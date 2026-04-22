defmodule Kiln.Telemetry.Otel do
  @moduledoc false

  # OBS-02: attach OpenTelemetry instrumenters after core boot checks pass.
  @spec setup() :: :ok
  def setup do
    _ = Application.ensure_all_started(:opentelemetry_exporter)

    OpentelemetryBandit.setup()
    OpentelemetryPhoenix.setup(adapter: :bandit, liveview: true)
    OpentelemetryEcto.setup([:kiln, :repo], db_statement: :disabled)
    OpentelemetryOban.setup()
    :ok
  end
end
