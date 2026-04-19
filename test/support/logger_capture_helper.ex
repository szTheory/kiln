defmodule Kiln.LoggerCaptureHelper do
  @moduledoc """
  Test helper for asserting structured metadata on log lines emitted
  through the `LoggerJSON.Formatters.Basic` pipeline (Plan 01-05 / OBS-01).

  `ExUnit.CaptureLog` intentionally runs its own temporary `:logger`
  handler with a plain-text formatter — so it does NOT exercise Kiln's
  JSON output path. This helper attaches a per-test `:logger` handler
  whose formatter is `LoggerJSON.Formatters.Basic` (same as the
  `:default_handler` in `config/config.exs`) and forwards each formatted
  line to the test process as a `{:log_line, binary}` message. The
  helper then drains the mailbox, decodes each line as JSON, and
  returns the list.

  Usage:

      import Kiln.LoggerCaptureHelper
      require Logger

      test "json metadata on every line" do
        {result, lines} =
          capture_json(fn ->
            Logger.info("hello")
            42
          end)

        assert result == 42
        assert [%{"message" => "hello", "metadata" => meta}] = lines
        assert meta["correlation_id"] in [nil, "none"]
      end

  The handler uses `Kiln.Logger.Metadata.default_filter/2` so the six
  D-46 mandatory keys render on every captured line (defaulting to
  `"none"` when absent).
  """

  alias Kiln.Logger.Metadata
  alias LoggerJSON.Formatters.Basic

  @doc """
  Captures every log line emitted inside `fun` as JSON. Returns
  `{fun_return_value, [decoded_json_line, ...]}` in emission order.
  """
  @spec capture_json((-> any())) :: {any(), [map()]}
  def capture_json(fun) when is_function(fun, 0) do
    parent = self()
    handler_id = :"#{__MODULE__}_#{System.unique_integer([:positive])}"

    formatter = Basic.new(metadata: Metadata.mandatory_keys())

    # Erlang's logger has a primary-level filter that drops events BELOW
    # that level before they reach any handler. `config/test.exs` sets
    # `config :logger, level: :warning` to quiet dev-noise during
    # `mix test`, which would discard every `Logger.info/1` the D-47
    # tests emit. Temporarily lower the primary to `:all` for the span
    # of the capture, and restore it in the `after` clause so other
    # tests keep their configured level.
    prior_primary = :logger.get_primary_config()
    :ok = :logger.set_primary_config(:level, :all)

    :ok =
      :logger.add_handler(
        handler_id,
        __MODULE__,
        %{
          level: :all,
          config: %{parent: parent},
          formatter: formatter,
          filter_default: :log,
          filters: [
            kiln_metadata_defaults: {&Metadata.default_filter/2, []}
          ]
        }
      )

    try do
      result = fun.()
      # Give the logger time to flush emitted events. Logger.flush/0
      # syncs the default handler; our custom handler is called inline
      # from the log macro, so the send has already happened by the
      # time fun.() returns.
      Logger.flush()
      lines = drain_json_lines()
      {result, lines}
    after
      :logger.remove_handler(handler_id)
      :logger.set_primary_config(:level, prior_primary.level)
    end
  end

  require Logger

  # ──────────────────────────────────────────────────────────────────
  # `:logger` handler callbacks (Erlang callback module contract).
  #
  # These four functions are invoked by Erlang's `:logger` framework,
  # so they must be public — they are NOT part of the caller-facing
  # API surface (tests call `capture_json/1` only). Documented here
  # rather than marked `@doc false` to satisfy the ex_slop
  # `DocFalseOnPublicFunction` check.

  @doc """
  `:logger` handler hot-path callback. Formats the log event via the
  configured `LoggerJSON.Formatters.Basic` formatter and sends the
  resulting binary to the registered parent process.
  """
  def log(%{meta: _} = log_event, %{formatter: {mod, cfg}, config: %{parent: parent}}) do
    iodata = mod.format(log_event, cfg)
    send(parent, {:log_line, IO.iodata_to_binary(iodata)})
    :ok
  end

  @doc """
  `:logger` handler lifecycle: called once when the handler is attached
  via `:logger.add_handler/3`. Returns the config unchanged.
  """
  def adding_handler(config), do: {:ok, config}

  @doc """
  `:logger` handler lifecycle: called once when the handler is removed
  via `:logger.remove_handler/1`. No teardown required.
  """
  def removing_handler(_config), do: :ok

  @doc """
  `:logger` handler lifecycle: called when `:logger.set_handler_config/3`
  or `:logger.update_handler_config/3` mutates the handler config.
  Accepts the new config unchanged.
  """
  def changing_config(_set_or_update, _old_config, new_config), do: {:ok, new_config}

  defp drain_json_lines(acc \\ []) do
    receive do
      {:log_line, raw} ->
        case Jason.decode(raw) do
          {:ok, map} -> drain_json_lines([map | acc])
          _ -> drain_json_lines(acc)
        end
    after
      0 -> Enum.reverse(acc)
    end
  end
end
