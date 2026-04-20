defmodule Kiln.Blockers.PlaybookRegistry do
  @moduledoc """
  Compile-time registry of blocker playbooks (D-136 — 4th instance of the
  compile-time registry pattern, mirror of `Kiln.Audit.SchemaRegistry`,
  `Kiln.Stages.ContractRegistry`, `Kiln.Workflows.SchemaRegistry`).

  Walks `priv/playbooks/v1/*.md` at compile time, splits each into
  `{frontmatter, body}` pairs, parses YAML via `YamlElixir`, JSV-validates
  each frontmatter against `priv/playbook_schemas/v1/playbook.json`, and
  stores in a compile-time `@playbooks` map keyed by reason atom.

  A reason atom without a matching .md file triggers `CompileError`.
  A frontmatter that fails JSV validation also triggers `CompileError` —
  edits fail `mix compile` with a readable error before landing.
  """

  alias Kiln.Blockers.{Playbook, Reason, RenderedPlaybook}

  @playbooks_dir Path.expand("../../../priv/playbooks/v1", __DIR__)
  @schema_path Path.expand("../../../priv/playbook_schemas/v1/playbook.json", __DIR__)
  @build_opts [default_meta: "https://json-schema.org/draft/2020-12/schema"]

  # Register the schema file as an external resource so any edit triggers
  # recompile of this module.
  @external_resource @schema_path
  @playbook_schema JSV.build!(Jason.decode!(File.read!(@schema_path)), @build_opts)

  # Compile-time frontmatter splitter regex. Anchored at \A (start-of-string)
  # and \z (end-of-string) so the split is state-machine-like: capture the
  # first "---\n...\n---\n" block from the START. Not vulnerable to body
  # "\n---\n" occurrences (e.g. a horizontal rule in playbook prose).
  @frontmatter_regex ~r/\A---\n(.*?)\n---\n(.*)\z/s

  @playbooks (for reason <- Reason.all(), into: %{} do
                path = Path.join(@playbooks_dir, "#{reason}.md")
                @external_resource path

                case File.read(path) do
                  {:ok, raw} ->
                    {frontmatter, body} =
                      case Regex.run(@frontmatter_regex, raw, capture: :all_but_first) do
                        [fm, b] ->
                          {fm, b}

                        nil ->
                          raise CompileError,
                            description:
                              "Playbook #{reason}.md missing YAML frontmatter delimiters " <>
                                "(expected \"---\\n...\\n---\\n\" prefix)"
                      end

                    parsed = YamlElixir.read_from_string!(frontmatter)

                    case JSV.validate(parsed, @playbook_schema) do
                      {:ok, _} ->
                        pb = %Playbook{
                          reason: reason,
                          frontmatter: parsed,
                          body_markdown: body
                        }

                        {reason, pb}

                      {:error, err} ->
                        raise CompileError,
                          description:
                            "Playbook frontmatter validation failed for #{reason}: " <>
                              inspect(err)
                    end

                  {:error, :enoent} ->
                    raise CompileError,
                      description:
                        "Missing playbook file priv/playbooks/v1/#{reason}.md — every " <>
                          "Kiln.Blockers.Reason atom must have a playbook"
                end
              end)

  @doc """
  Returns `{:ok, playbook}` for a known reason, `{:error, :unknown_reason}`
  otherwise.
  """
  @spec fetch(Reason.t() | atom()) :: {:ok, Playbook.t()} | {:error, :unknown_reason}
  def fetch(reason) when is_atom(reason) do
    case Map.get(@playbooks, reason) do
      nil -> {:error, :unknown_reason}
      pb -> {:ok, pb}
    end
  end

  @doc """
  Renders a playbook with Mustache `{var}` substitution from `context`.
  Unknown keys are preserved as `{key}` literals so missing context surfaces
  as operator-visible "not-yet-wired" text rather than a crash.
  """
  @spec render(Reason.t() | atom(), map()) ::
          {:ok, RenderedPlaybook.t()} | {:error, :unknown_reason}
  def render(reason, context) when is_atom(reason) and is_map(context) do
    with {:ok, pb} <- fetch(reason) do
      fm = pb.frontmatter

      {:ok,
       %RenderedPlaybook{
         reason: reason,
         title: substitute(fm["title"] || "", context),
         severity: fm["severity"],
         short_message: substitute(fm["short_message"] || "", context),
         commands:
           for cmd <- fm["remediation_commands"] || [] do
             %{
               label: substitute(cmd["label"], context),
               command: substitute(cmd["command"], context)
             }
           end,
         body_markdown: substitute(pb.body_markdown, context),
         next_action_on_resolve: fm["next_action_on_resolve"]
       }}
    end
  end

  # Minimal Mustache-style `{var}` substitution. Values stringified via
  # `to_string/1`. Preserves unsubstituted tokens as literals so operators
  # see a clear "not wired" signal rather than a crash.
  @spec substitute(String.t(), map()) :: String.t()
  defp substitute(template, ctx) when is_binary(template) and is_map(ctx) do
    Regex.replace(~r/\{(\w+)\}/, template, fn full, key ->
      case Map.fetch(ctx, String.to_atom(key)) do
        {:ok, val} ->
          to_string(val)

        :error ->
          case Map.fetch(ctx, key) do
            {:ok, val} -> to_string(val)
            # Preserve the full `{key}` literal — `full` is the whole match.
            :error -> full
          end
      end
    end)
  end
end
