defmodule Kiln.Telemetry.ObanHandler do
  @moduledoc """
  Telemetry handler for Oban job-lifecycle events. Restores the
  enqueueing process's Logger metadata inside the worker process on
  `[:oban, :job, :start]` by unpacking the `kiln_ctx` entry from
  `job.meta` (set at enqueue time via `Kiln.Telemetry.pack_meta/0`).

  This is the mechanical glue that makes behavior LOG-02 true: a log
  line emitted from inside `Oban.Worker.perform/1` carries the
  enqueueing caller's `correlation_id` because this handler runs
  **in the worker process** before `perform/1` executes.

  Attached once at application boot in `Kiln.Application.start/2`
  (NOT as a supervision-tree child — telemetry handlers are ETS-based,
  not process-based).
  """

  alias Kiln.Telemetry

  @handler_id {__MODULE__, :oban_job_lifecycle}

  @doc """
  Attaches the handler to `[:oban, :job, :start]` and
  `[:oban, :job, :stop]`. Idempotent: if the handler is already
  attached (e.g. from a prior `:telemetry.attach_many/4` call during
  tests), returns `{:error, :already_exists}` without raising.
  """
  @spec attach() :: :ok | {:error, :already_exists}
  def attach do
    :telemetry.attach_many(
      @handler_id,
      [
        [:oban, :job, :start],
        [:oban, :job, :stop]
      ],
      &__MODULE__.handle_event/4,
      nil
    )
  end

  @doc """
  Detaches the handler. Useful for test teardown; not called in
  production code paths.
  """
  @spec detach() :: :ok | {:error, :not_found}
  def detach do
    :telemetry.detach(@handler_id)
  end

  @doc false
  def handle_event(
        [:oban, :job, :start],
        _measurements,
        %{job: %{meta: %{"kiln_ctx" => ctx}}},
        _config
      )
      when is_map(ctx) do
    Telemetry.unpack_ctx(ctx)
  end

  def handle_event([:oban, :job, :start], _measurements, _metadata, _config), do: :ok
  def handle_event([:oban, :job, :stop], _measurements, _metadata, _config), do: :ok
end
