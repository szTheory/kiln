defmodule Kiln.Attach.BrownfieldPreflight do
  @moduledoc """
  Advisory brownfield preflight for attached-repo request launches.
  """

  alias Ecto.Changeset
  alias Kiln.Attach.AttachedRepo
  alias Kiln.Attach.IntakeRequest
  alias Kiln.GitHub.Cli
  alias Kiln.Runs
  alias Kiln.Runs.Run
  alias Kiln.Specs
  alias Kiln.Specs.{Spec, SpecDraft, SpecRevision}

  @type severity :: :fatal | :warning | :info

  @type finding :: %{
          severity: severity(),
          code: atom(),
          title: String.t(),
          why: String.t(),
          next_action: String.t(),
          evidence: map()
        }

  @type request :: %{
          request_kind: IntakeRequest.request_kind() | nil,
          title: String.t() | nil,
          change_summary: String.t() | nil,
          acceptance_criteria: [String.t()],
          out_of_scope: [String.t()]
        }

  @type report :: %{
          attached_repo_id: Ecto.UUID.t(),
          repo_slug: String.t(),
          base_branch: String.t() | nil,
          request: request(),
          findings: [finding()],
          suggested_request: request() | nil
        }

  @spec evaluate(AttachedRepo.t(), map(), keyword()) :: report()
  def evaluate(%AttachedRepo{} = attached_repo, params, opts \\ []) when is_map(params) do
    request = normalize_request(params)
    open_prs = open_prs(attached_repo, opts)

    findings =
      [
        same_lane_run_finding(attached_repo, opts),
        same_lane_pr_finding(attached_repo, open_prs),
        open_pr_overlap_finding(attached_repo, open_prs),
        overlap_finding(attached_repo, request, opts),
        breadth_finding(attached_repo, request),
        pr_lookup_unavailable_finding(attached_repo, open_prs),
        recent_context_finding(attached_repo, opts)
      ]
      |> Enum.reject(&is_nil/1)
      |> Enum.sort_by(&severity_rank/1)

    %{
      attached_repo_id: attached_repo.id,
      repo_slug: attached_repo.repo_slug,
      base_branch: attached_repo.base_branch,
      request: request,
      findings: findings,
      suggested_request: suggested_request(request, findings)
    }
  end

  @spec fatal?(report()) :: boolean()
  def fatal?(report), do: Enum.any?(report.findings, &(&1.severity == :fatal))

  @spec warning?(report()) :: boolean()
  def warning?(report), do: Enum.any?(report.findings, &(&1.severity == :warning))

  @spec info?(report()) :: boolean()
  def info?(report), do: Enum.any?(report.findings, &(&1.severity == :info))

  @spec launchable?(report()) :: boolean()
  def launchable?(report), do: not fatal?(report)

  @spec needs_narrowing?(report()) :: boolean()
  def needs_narrowing?(report), do: launchable?(report) and warning?(report)

  @spec fatal_findings(report()) :: [finding()]
  def fatal_findings(report), do: Enum.filter(report.findings, &(&1.severity == :fatal))

  @spec warning_findings(report()) :: [finding()]
  def warning_findings(report), do: Enum.filter(report.findings, &(&1.severity == :warning))

  defp normalize_request(params) do
    %IntakeRequest{}
    |> IntakeRequest.changeset(stringify_keys(params))
    |> normalized_request_from_changeset()
  end

  defp normalized_request_from_changeset(changeset) do
    %{
      request_kind: Changeset.get_field(changeset, :request_kind),
      title: Changeset.get_field(changeset, :title),
      change_summary: Changeset.get_field(changeset, :change_summary),
      acceptance_criteria: Changeset.get_field(changeset, :acceptance_criteria) || [],
      out_of_scope: Changeset.get_field(changeset, :out_of_scope) || []
    }
  end

  defp same_lane_run_finding(%AttachedRepo{} = attached_repo, opts) do
    attached_repo.id
    |> recent_runs(opts)
    |> Enum.find(fn run ->
      base_branch = get_in(run.github_delivery_snapshot, ["attach", "base_branch"])
      branch = get_in(run.github_delivery_snapshot, ["attach", "branch"])

      run.state in Run.active_states() and base_branch == attached_repo.base_branch and
        is_binary(branch) and branch != ""
    end)
    |> case do
      %Run{} = run ->
        %{
          severity: :fatal,
          code: :same_lane_ambiguity,
          title: "Kiln already has an active same-lane run",
          why:
            "This attached repo already has an active Kiln lane targeting the same base branch.",
          next_action:
            "Inspect the active run and finish or cancel it before starting another branch in the same lane.",
          evidence: %{
            attached_repo_id: attached_repo.id,
            repo_slug: attached_repo.repo_slug,
            base_branch: attached_repo.base_branch,
            run_id: run.id,
            run_state: run.state,
            branch: get_in(run.github_delivery_snapshot, ["attach", "branch"])
          }
        }

      nil ->
        nil
    end
  end

  defp same_lane_pr_finding(%AttachedRepo{} = attached_repo, {:ok, open_prs}) do
    Enum.find(open_prs, fn pr ->
      pr_base_branch(pr) == attached_repo.base_branch and
        String.starts_with?(pr_head_branch(pr), "kiln/attach/")
    end)
    |> case do
      nil ->
        nil

      pr ->
        %{
          severity: :fatal,
          code: :same_lane_ambiguity,
          title: "An open Kiln PR already occupies this lane",
          why:
            "Kiln found an in-flight PR on the same repo and base branch, so launching another lane would be ambiguous.",
          next_action:
            "Inspect the existing PR and either merge, close, or explicitly resolve that lane before starting another run.",
          evidence: %{
            attached_repo_id: attached_repo.id,
            repo_slug: attached_repo.repo_slug,
            base_branch: attached_repo.base_branch,
            pr_number: pr["number"],
            pr_title: pr["title"],
            pr_url: pr["url"],
            branch: pr_head_branch(pr)
          }
        }
    end
  end

  defp same_lane_pr_finding(_attached_repo, _result), do: nil

  defp open_pr_overlap_finding(%AttachedRepo{} = attached_repo, {:ok, open_prs}) do
    overlaps =
      Enum.filter(open_prs, fn pr ->
        pr_base_branch(pr) == attached_repo.base_branch and
          not String.starts_with?(pr_head_branch(pr), "kiln/attach/")
      end)

    case overlaps do
      [pr | _] ->
        %{
          severity: :warning,
          code: :open_pr_overlap,
          title: "Another open PR already targets this base branch",
          why:
            "An open PR on the same repo and base branch may overlap with the request you are about to launch.",
          next_action: "Inspect the open PR and narrow this request if it touches the same lane.",
          evidence: %{
            attached_repo_id: attached_repo.id,
            repo_slug: attached_repo.repo_slug,
            base_branch: attached_repo.base_branch,
            pr_number: pr["number"],
            pr_title: pr["title"],
            pr_url: pr["url"],
            branch: pr_head_branch(pr)
          }
        }

      _ ->
        nil
    end
  end

  defp open_pr_overlap_finding(_attached_repo, _result), do: nil

  defp overlap_finding(%AttachedRepo{} = attached_repo, request, opts) do
    request_tokens = request_tokens(request)

    candidates =
      overlap_candidates(attached_repo, opts)
      |> Enum.map(&score_candidate(&1, request, request_tokens))
      |> Enum.reject(&(candidate_score(&1) < 0.35))
      |> Enum.sort_by(&candidate_score/1, :desc)

    case List.first(candidates) do
      %{candidate: candidate, score: score} when score >= 0.65 ->
        overlap_warning(:possible_duplicate, attached_repo, candidate)

      %{candidate: candidate, score: score} when score >= 0.35 ->
        overlap_warning(:possible_overlap, attached_repo, candidate)

      _ ->
        nil
    end
  end

  defp overlap_warning(code, attached_repo, candidate) do
    %{
      severity: :warning,
      code: code,
      title:
        if(code == :possible_duplicate,
          do: "This request looks very close to recent same-repo work",
          else: "This request may overlap recent same-repo work"
        ),
      why:
        if(code == :possible_duplicate,
          do:
            "Kiln found strong same-repo overlap signals against recent attached work in this repo.",
          else:
            "Kiln found moderate same-repo overlap signals against recent attached work in this repo."
        ),
      next_action: "Inspect the prior object and narrow this request before starting coding.",
      evidence: %{
        attached_repo_id: attached_repo.id,
        repo_slug: attached_repo.repo_slug,
        base_branch: attached_repo.base_branch,
        prior_kind: candidate.kind,
        prior_title: candidate.title,
        prior_request_kind: candidate.request_kind,
        draft_id: candidate.draft_id,
        spec_revision_id: candidate.spec_revision_id,
        run_id: candidate.run_id,
        branch: candidate.branch
      }
    }
  end

  defp breadth_finding(%AttachedRepo{} = attached_repo, request) do
    token_count =
      request
      |> request_tokens()
      |> MapSet.size()

    if length(request.acceptance_criteria) > 2 or length(request.out_of_scope) > 2 or
         token_count > 22 do
      %{
        severity: :warning,
        code: :request_too_broad,
        title: "This request looks broader than one conservative PR lane",
        why:
          "The requested scope carries multiple outcomes, which increases collision risk before coding starts.",
        next_action:
          "Accept Kiln's narrower default or edit the request so one PR-sized outcome stays in scope.",
        evidence: %{
          attached_repo_id: attached_repo.id,
          repo_slug: attached_repo.repo_slug,
          base_branch: attached_repo.base_branch,
          acceptance_criteria_count: length(request.acceptance_criteria),
          out_of_scope_count: length(request.out_of_scope),
          token_count: token_count
        }
      }
    end
  end

  defp pr_lookup_unavailable_finding(%AttachedRepo{} = attached_repo, {:error, reason}) do
    %{
      severity: :warning,
      code: :pr_lookup_unavailable,
      title: "Kiln could not confirm the live open-PR lane check",
      why:
        "The brownfield preflight could not read open PR state, so overlap guidance is running with reduced confidence.",
      next_action:
        "Continue only if you have manually checked for an in-flight PR on this repo and base branch.",
      evidence: %{
        attached_repo_id: attached_repo.id,
        repo_slug: attached_repo.repo_slug,
        base_branch: attached_repo.base_branch,
        reason: reason
      }
    }
  end

  defp pr_lookup_unavailable_finding(_attached_repo, _result), do: nil

  defp recent_context_finding(%AttachedRepo{} = attached_repo, opts) do
    counts = %{
      open_drafts: length(open_drafts(attached_repo.id, opts)),
      promoted_requests: length(recent_promoted_requests(attached_repo.id, opts)),
      recent_runs: length(recent_runs(attached_repo.id, opts))
    }

    if Enum.any?(counts, fn {_key, count} -> count > 0 end) do
      %{
        severity: :info,
        code: :recent_repo_context,
        title: "Kiln found recent same-repo context",
        why:
          "This repo already has recent attached-repo history, which Kiln used when it evaluated brownfield overlap risk.",
        next_action:
          "Inspect the recent same-repo objects if you want extra context before starting this run.",
        evidence:
          Map.merge(counts, %{
            attached_repo_id: attached_repo.id,
            repo_slug: attached_repo.repo_slug,
            base_branch: attached_repo.base_branch
          })
      }
    end
  end

  defp suggested_request(request, findings) do
    if Enum.any?(
         findings,
         &(&1.code in [:possible_duplicate, :possible_overlap, :request_too_broad])
       ) do
      %{
        request_kind: request.request_kind,
        title: request.title,
        change_summary: first_sentence(request.change_summary),
        acceptance_criteria: Enum.take(request.acceptance_criteria, 2),
        out_of_scope: Enum.take(request.out_of_scope, 2)
      }
    end
  end

  defp overlap_candidates(%AttachedRepo{} = attached_repo, opts) do
    drafts =
      attached_repo.id
      |> open_drafts(opts)
      |> Enum.map(&candidate_from_draft/1)

    promoted =
      attached_repo.id
      |> recent_promoted_requests(opts)
      |> Enum.map(&candidate_from_promoted_request/1)

    runs =
      attached_repo.id
      |> recent_runs(opts)
      |> Enum.map(&candidate_from_run/1)
      |> Enum.reject(&is_nil/1)

    drafts ++ promoted ++ runs
  end

  defp candidate_from_draft(%SpecDraft{} = draft) do
    %{
      kind: :draft,
      draft_id: draft.id,
      run_id: nil,
      spec_revision_id: nil,
      title: draft.title,
      request_kind: draft.request_kind,
      change_summary: draft.change_summary,
      acceptance_criteria: draft.acceptance_criteria || [],
      out_of_scope: draft.out_of_scope || [],
      branch: nil,
      active?: true
    }
  end

  defp candidate_from_promoted_request(%{
         spec: %Spec{} = spec,
         revision: %SpecRevision{} = revision
       }) do
    %{
      kind: :promoted_request,
      draft_id: nil,
      run_id: nil,
      spec_revision_id: revision.id,
      title: spec.title,
      request_kind: revision.request_kind,
      change_summary: revision.change_summary,
      acceptance_criteria: revision.acceptance_criteria || [],
      out_of_scope: revision.out_of_scope || [],
      branch: nil,
      active?: false
    }
  end

  defp candidate_from_run(%Run{} = run) do
    case {run.spec, run.spec_revision} do
      {%Spec{} = spec, %SpecRevision{} = revision} ->
        %{
          kind: :run,
          draft_id: nil,
          run_id: run.id,
          spec_revision_id: revision.id,
          title: spec.title,
          request_kind: revision.request_kind,
          change_summary: revision.change_summary,
          acceptance_criteria: revision.acceptance_criteria || [],
          out_of_scope: revision.out_of_scope || [],
          branch: get_in(run.github_delivery_snapshot, ["attach", "branch"]),
          active?: run.state in Run.active_states()
        }

      _ ->
        nil
    end
  end

  defp score_candidate(candidate, request, request_tokens) do
    candidate_tokens =
      %{
        title: candidate.title,
        change_summary: candidate.change_summary,
        acceptance_criteria: candidate.acceptance_criteria,
        out_of_scope: candidate.out_of_scope
      }
      |> request_tokens()

    intersection = MapSet.intersection(request_tokens, candidate_tokens) |> MapSet.size()
    request_size = max(MapSet.size(request_tokens), 1)
    candidate_size = max(MapSet.size(candidate_tokens), 1)
    ratio = intersection / min(request_size, candidate_size)

    title_exact? =
      normalize_text(request.title || "") != "" and
        normalize_text(request.title || "") == normalize_text(candidate.title || "")

    score =
      ratio
      |> maybe_boost(title_exact?, 0.35)
      |> maybe_boost(request.request_kind == candidate.request_kind, 0.1)
      |> maybe_boost(candidate.active?, 0.1)

    %{candidate: candidate, score: min(score, 1.0)}
  end

  defp maybe_boost(score, true, amount), do: score + amount
  defp maybe_boost(score, false, _amount), do: score

  defp candidate_score(%{score: score}), do: score

  defp request_tokens(%{
         title: title,
         change_summary: summary,
         acceptance_criteria: acceptance,
         out_of_scope: out
       }) do
    stop_words = stop_words()

    [title, summary | acceptance ++ out]
    |> Enum.reject(&is_nil/1)
    |> Enum.map(&normalize_text/1)
    |> Enum.join(" ")
    |> String.split(" ", trim: true)
    |> Enum.reject(&(String.length(&1) < 3 or &1 in stop_words))
    |> MapSet.new()
  end

  defp stop_words, do: ["and", "the", "for", "with", "this", "that", "from", "into", "one", "two"]

  defp severity_rank(%{severity: :fatal}), do: 0
  defp severity_rank(%{severity: :warning}), do: 1
  defp severity_rank(%{severity: :info}), do: 2

  defp normalize_text(text) when is_binary(text) do
    text
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/u, " ")
    |> String.trim()
  end

  defp stringify_keys(params) do
    Map.new(params, fn
      {key, value} when is_atom(key) -> {Atom.to_string(key), value}
      {key, value} -> {key, value}
    end)
  end

  defp first_sentence(nil), do: nil

  defp first_sentence(text) do
    text
    |> String.split(~r/[.!?]\s+/, parts: 2)
    |> List.first()
  end

  defp open_drafts(attached_repo_id, opts) do
    fun = Keyword.get(opts, :open_drafts_fn, &Specs.list_open_attached_drafts/2)
    fun.(attached_repo_id, limit: 5)
  end

  defp recent_promoted_requests(attached_repo_id, opts) do
    fun =
      Keyword.get(
        opts,
        :recent_promoted_requests_fn,
        &Specs.list_recent_promoted_attached_requests/2
      )

    fun.(attached_repo_id, limit: 5)
  end

  defp recent_runs(attached_repo_id, opts) do
    fun = Keyword.get(opts, :recent_runs_fn, &Runs.list_recent_for_attached_repo/2)
    fun.(attached_repo_id, limit: 5)
  end

  defp open_prs(%AttachedRepo{} = attached_repo, opts) do
    case Keyword.get(opts, :list_open_prs_fn) do
      nil -> run_open_pr_lookup(attached_repo, opts)
      fun when is_function(fun, 2) -> fun.(attached_repo, opts)
    end
  end

  defp run_open_pr_lookup(%AttachedRepo{} = attached_repo, opts) do
    argv = [
      "pr",
      "list",
      "--repo",
      attached_repo.repo_slug,
      "--state",
      "open",
      "--base",
      attached_repo.base_branch || "main",
      "--json",
      "number,title,url,headRefName,baseRefName,isDraft"
    ]

    runner_opts = [cd: attached_repo.workspace_path]

    case gh_call(Keyword.get(opts, :gh_runner, Cli.default_runner()), argv, runner_opts) do
      {:ok, output} ->
        case Jason.decode(output) do
          {:ok, prs} when is_list(prs) -> {:ok, prs}
          {:ok, other} -> {:error, {:invalid_pr_list_shape, other}}
          {:error, reason} -> {:error, {:invalid_pr_list_json, reason}}
        end

      {:error, %{stderr: stderr, exit_status: status}} ->
        {:error, %{code: Cli.classify_gh_error(stderr || "", status), stderr: stderr}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp gh_call(runner, argv, opts) when is_function(runner, 2), do: runner.(argv, opts)
  defp gh_call(runner, argv, opts) when is_atom(runner), do: runner.run_gh(argv, opts)

  defp pr_base_branch(pr), do: pr["baseRefName"] || ""
  defp pr_head_branch(pr), do: pr["headRefName"] || ""
end
