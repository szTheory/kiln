defmodule Kiln.OperatorReadiness do
  @moduledoc """
  BLOCK-04 — persisted operator environment probes (Anthropic ref, GitHub CLI,
  Docker). `ready?/0` aggregates the singleton `operator_readiness` row.

  Set `KILN_SKIP_OPERATOR_READINESS=1` to bypass checks locally (same spirit
  as `KILN_SKIP_BOOTCHECKS` — D-811).
  """

  import Ecto.Changeset, only: [change: 2]

  alias Kiln.OperatorReadiness.ProbeRow
  alias Kiln.Repo

  @singleton_id 1

  @spec ready?() :: boolean()
  def ready? do
    System.get_env("KILN_SKIP_OPERATOR_READINESS") == "1" or row_ready?()
  end

  defp row_ready? do
    case Repo.get(ProbeRow, @singleton_id) do
      %ProbeRow{} = r ->
        r.anthropic_configured and r.github_cli_ok and r.docker_ok

      nil ->
        true
    end
  end

  @doc """
  Updates one probe flag on the singleton row (upserts row `id=1`).
  """
  @spec mark_step(:anthropic | :github | :docker, boolean()) ::
          {:ok, ProbeRow.t()} | {:error, Ecto.Changeset.t()}
  def mark_step(step, value) when is_boolean(value) and step in [:anthropic, :github, :docker] do
    field =
      case step do
        :anthropic -> :anthropic_configured
        :github -> :github_cli_ok
        :docker -> :docker_ok
      end

    row = Repo.get!(ProbeRow, @singleton_id)

    row
    |> change([{field, value}])
    |> Repo.update()
  end

  @doc """
  Returns the current persisted probe state as a plain map plus a
  verified/total count. Used by the onboarding wizard to show stateful
  step chips without each step touching the repo itself.
  """
  @spec current_state() :: %{
          anthropic: boolean(),
          github: boolean(),
          docker: boolean(),
          verified: non_neg_integer(),
          total: non_neg_integer()
        }
  def current_state do
    row =
      case Repo.get(ProbeRow, @singleton_id) do
        %ProbeRow{} = r -> r
        _ -> %ProbeRow{anthropic_configured: false, github_cli_ok: false, docker_ok: false}
      end

    flags = [row.anthropic_configured, row.github_cli_ok, row.docker_ok]
    verified = Enum.count(flags, & &1)

    %{
      anthropic: row.anthropic_configured || false,
      github: row.github_cli_ok || false,
      docker: row.docker_ok || false,
      verified: verified,
      total: length(flags)
    }
  end

  @doc false
  @spec probe_anthropic_configured?() :: boolean()
  def probe_anthropic_configured? do
    ref = Application.get_env(:kiln, :anthropic_api_key_ref)
    is_binary(ref) and ref != ""
  end

  @doc false
  @spec probe_github_cli?() :: boolean()
  def probe_github_cli? do
    case System.cmd("gh", ["auth", "status"], stderr_to_stdout: true, env: []) do
      {_out, 0} -> true
      _ -> false
    end
  end

  @doc false
  @spec probe_docker?() :: boolean()
  def probe_docker? do
    case System.cmd("docker", ["info"], stderr_to_stdout: true, env: []) do
      {_out, 0} -> true
      _ -> false
    end
  end
end
