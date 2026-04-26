defmodule Kiln.Attach.BrownfieldPreflightTest do
  use ExUnit.Case, async: true

  alias Kiln.Attach
  alias Kiln.Attach.AttachedRepo
  alias Kiln.Attach.BrownfieldPreflight
  alias Kiln.Runs.Run
  alias Kiln.Specs.{Spec, SpecDraft, SpecRevision}

  test "attach seam returns a typed report with launchability helpers" do
    report =
      Attach.evaluate_brownfield_preflight(attached_repo_fixture(), request_params(),
        open_drafts_fn: fn _, _ -> [overlapping_draft()] end,
        recent_promoted_requests_fn: fn _, _ -> [] end,
        recent_runs_fn: fn _, _ -> [] end,
        list_open_prs_fn: fn _, _ -> {:ok, []} end
      )

    assert is_list(report.findings)
    assert Enum.any?(report.findings, &(&1.severity == :warning))
    assert Enum.any?(report.findings, &(&1.severity == :info))
    assert BrownfieldPreflight.launchable?(report)
    assert BrownfieldPreflight.warning?(report)
    refute BrownfieldPreflight.fatal?(report)
  end

  test "fatal findings carry deterministic evidence and block launchability" do
    report =
      Attach.evaluate_brownfield_preflight(attached_repo_fixture(), request_params(),
        open_drafts_fn: fn _, _ -> [] end,
        recent_promoted_requests_fn: fn _, _ -> [] end,
        recent_runs_fn: fn _, _ -> [] end,
        list_open_prs_fn: fn _, _ ->
          {:ok,
           [
             %{
               "number" => 42,
               "title" => "draft: kiln lane",
               "url" => "https://github.com/jon/kiln/pull/42",
               "baseRefName" => "main",
               "headRefName" => "kiln/attach/jon-kiln-r123"
             }
           ]}
        end
      )

    assert BrownfieldPreflight.fatal?(report)
    refute BrownfieldPreflight.launchable?(report)

    [finding | _] = BrownfieldPreflight.fatal_findings(report)
    assert finding.code == :same_lane_ambiguity
    assert finding.evidence.pr_number == 42
    assert finding.evidence.branch == "kiln/attach/jon-kiln-r123"
  end

  test "broad requests produce a narrower default without becoming hard refusals" do
    report =
      BrownfieldPreflight.evaluate(
        attached_repo_fixture(),
        %{
          "request_kind" => "feature",
          "title" => "Refactor attach flow and continuity handoff and warning rendering",
          "change_summary" =>
            "Tighten attach warning UX. Update continuity carry-forward. Add start guardrails.",
          "acceptance_criteria" => ["first", "second", "third"],
          "out_of_scope" => ["one", "two", "three"]
        },
        open_drafts_fn: fn _, _ -> [] end,
        recent_promoted_requests_fn: fn _, _ -> [] end,
        recent_runs_fn: fn _, _ -> [] end,
        list_open_prs_fn: fn _, _ -> {:ok, []} end
      )

    assert BrownfieldPreflight.needs_narrowing?(report)
    assert report.suggested_request.acceptance_criteria == ["first", "second"]
    assert report.suggested_request.out_of_scope == ["one", "two"]
  end

  test "pr lookup failure becomes a typed non-fatal warning" do
    report =
      BrownfieldPreflight.evaluate(attached_repo_fixture(), request_params(),
        open_drafts_fn: fn _, _ -> [] end,
        recent_promoted_requests_fn: fn _, _ -> [] end,
        recent_runs_fn: fn _, _ -> [] end,
        list_open_prs_fn: fn _, _ -> {:error, :timeout} end
      )

    assert BrownfieldPreflight.launchable?(report)
    assert Enum.any?(report.findings, &(&1.code == :pr_lookup_unavailable))
  end

  test "recent repo history can surface as info without affecting launchability" do
    run =
      %Run{
        id: "run-123",
        state: :merged,
        github_delivery_snapshot: %{"attach" => %{"base_branch" => "main", "branch" => "topic"}},
        spec: %Spec{id: "spec-123", title: "Earlier attached repo request"},
        spec_revision: %SpecRevision{
          id: "rev-123",
          spec_id: "spec-123",
          request_kind: :feature,
          change_summary: "Earlier work",
          acceptance_criteria: ["old criterion"],
          out_of_scope: ["old scope"]
        }
      }

    report =
      BrownfieldPreflight.evaluate(
        attached_repo_fixture(),
        %{
          "request_kind" => "bugfix",
          "title" => "Fix settings copy",
          "change_summary" => "Tighten the attach settings link copy.",
          "acceptance_criteria" => ["copy is accurate"]
        },
        open_drafts_fn: fn _, _ -> [] end,
        recent_promoted_requests_fn: fn _, _ -> [] end,
        recent_runs_fn: fn _, _ -> [run] end,
        list_open_prs_fn: fn _, _ -> {:ok, []} end
      )

    assert BrownfieldPreflight.info?(report)
    assert BrownfieldPreflight.launchable?(report)
    refute BrownfieldPreflight.needs_narrowing?(report)
  end

  defp attached_repo_fixture do
    %AttachedRepo{
      id: "attached-123",
      repo_slug: "jon/kiln",
      workspace_path: "/tmp/kiln",
      base_branch: "main"
    }
  end

  defp overlapping_draft do
    %SpecDraft{
      id: "draft-123",
      title: "Tighten attach success flow",
      request_kind: :feature,
      change_summary: "Add one bounded launch path for ready attached repos.",
      acceptance_criteria: ["Ready state shows one bounded request form."],
      out_of_scope: ["Draft PR polish"]
    }
  end

  defp request_params do
    %{
      "request_kind" => "feature",
      "title" => "Tighten attach success flow",
      "change_summary" => "Add one bounded launch path for ready attached repos.",
      "acceptance_criteria" => ["Ready state shows one bounded request form."],
      "out_of_scope" => ["Draft PR polish"]
    }
  end
end
