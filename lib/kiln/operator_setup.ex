defmodule Kiln.OperatorSetup do
  @moduledoc """
  Aggregates the operator-facing setup story for onboarding, settings, and
  live-mode disconnected states.

  Secret values are never exposed. The surface only reports readiness booleans,
  provider names, and recovery guidance.
  """

  alias Kiln.ModelRegistry
  alias Kiln.OperatorReadiness

  @type checklist_item :: %{
          id: atom(),
          title: String.t(),
          status: :ready | :action_needed,
          why: String.t(),
          where_used: String.t(),
          next_action: String.t(),
          href: String.t(),
          probe: String.t()
        }

  @type provider_item :: %{
          id: atom(),
          name: String.t(),
          configured?: boolean(),
          status: :configured | :not_configured,
          note: String.t()
        }

  @type summary :: %{
          ready?: boolean(),
          blockers: [checklist_item()],
          checklist: [checklist_item()],
          providers: [provider_item()]
        }

  @type settings_target_opt ::
          {:return_to, String.t() | nil}
          | {:template_id, String.t() | nil}

  @spec summary() :: summary()
  def summary do
    checklist = checklist()

    %{
      ready?: Enum.all?(checklist, &(&1.status == :ready)),
      blockers: Enum.filter(checklist, &(&1.status == :action_needed)),
      checklist: checklist,
      providers: providers()
    }
  end

  @spec ready?() :: boolean()
  def ready? do
    summary().ready?
  end

  @spec checklist() :: [checklist_item()]
  def checklist do
    readiness = OperatorReadiness.current_state()

    [
      %{
        id: :anthropic,
        title: "Anthropic provider reference",
        status: step_status(readiness.anthropic),
        why: "Current default live planning and coding paths expect a Claude-capable provider.",
        where_used: "Templates, promoted runs, and first live dogfood workflows.",
        next_action:
          "Set the Anthropic secret reference in your runtime environment, then re-verify.",
        href: "/settings#settings-item-anthropic",
        probe: ":anthropic_api_key_ref"
      },
      %{
        id: :github,
        title: "GitHub CLI authentication",
        status: step_status(readiness.github),
        why:
          "GitHub-backed automation needs authenticated CLI access for issue, PR, and repo actions.",
        where_used: "Inbox, PR delivery, and external-repo dogfood workflows.",
        next_action: "Run gh auth login (or equivalent) on this machine, then re-verify.",
        href: "/settings#settings-item-github",
        probe: "gh auth status"
      },
      %{
        id: :docker,
        title: "Docker engine reachability",
        status: step_status(readiness.docker),
        why: "Sandbox-backed stages and DTU flows rely on the local Docker engine.",
        where_used: "Run execution, scenario verification, and integration smoke paths.",
        next_action: "Start Docker Desktop or your local engine, then re-verify.",
        href: "/settings#settings-item-docker",
        probe: "docker info"
      }
    ]
  end

  @spec providers() :: [provider_item()]
  def providers do
    ModelRegistry.provider_health_snapshots()
    |> Enum.map(fn snapshot ->
      %{
        id: snapshot.id,
        name: provider_name(snapshot.id),
        configured?: snapshot.key_configured?,
        status: if(snapshot.key_configured?, do: :configured, else: :not_configured),
        note:
          if snapshot.key_configured? do
            "Configured for runtime use."
          else
            "Not configured. Demo mode can still be explored without this."
          end
      }
    end)
  end

  @spec blocker_titles() :: [String.t()]
  def blocker_titles do
    summary().blockers
    |> Enum.map(& &1.title)
  end

  @spec first_blocker() :: checklist_item() | nil
  def first_blocker do
    summary()
    |> first_blocker_from_summary()
  end

  @spec settings_target(checklist_item() | nil, [settings_target_opt()]) :: String.t()
  def settings_target(blocker, opts \\ [])

  def settings_target(nil, opts) do
    build_settings_target("/settings", opts)
  end

  def settings_target(%{href: href}, opts) when is_binary(href) do
    build_settings_target(href, opts)
  end

  defp first_blocker_from_summary(%{blockers: [blocker | _]}), do: blocker
  defp first_blocker_from_summary(_), do: nil

  defp build_settings_target(base_href, opts) do
    uri = URI.parse(base_href)

    query =
      opts
      |> Enum.into(%{})
      |> Enum.reject(fn {_key, value} -> is_nil(value) or value == "" end)
      |> Map.new()

    uri
    |> Map.put(:query, if(query == %{}, do: nil, else: URI.encode_query(query)))
    |> URI.to_string()
  end

  defp step_status(true), do: :ready
  defp step_status(false), do: :action_needed

  defp provider_name(:anthropic), do: "Anthropic"
  defp provider_name(:openai), do: "OpenAI"
  defp provider_name(:google), do: "Google"
  defp provider_name(:ollama), do: "Ollama"
  defp provider_name(id), do: id |> to_string() |> String.capitalize()
end
