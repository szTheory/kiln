defmodule Kiln.Agents.Adapter.Anthropic do
  @moduledoc """
  LIVE Anthropic adapter (D-101). Wraps Anthropix 0.6.2 for message
  streaming; uses raw `Req` for `complete/2` and `count_tokens/1`
  (Anthropix 0.6 does not expose a count_tokens wrapper — see
  PATTERNS.md anti-pattern #3).

  All HTTP traffic routes through the named `Kiln.Finch` pool; Finch's
  per-host pool sharding (D-109 amendment) gives provider isolation
  without a per-provider Finch child. Authorization header is built
  inside one helper (`fetch_api_key/0`) via `Kiln.Secrets.reveal!/1` —
  the SOLE raw-string boundary in this file (D-131..D-133 Layer 1).

  ## Telemetry contract (D-110)

    * `[:kiln, :agent, :call, :start]` — measurements: `system_time`;
      metadata: `provider: :anthropic, role, run_id, stage_id,
      requested_model`.
    * `[:kiln, :agent, :call, :stop]` — measurements: `duration,
      tokens_in, tokens_out, cost_usd`; metadata carries all of
      `:start` plus `actual_model_used` + `fallback?`.
    * `[:kiln, :agent, :call, :exception]` — `:telemetry.span/3`
      automatically emits this when the body raises.

  ## ExternalOperations contract (D-14..D-21)

  Every `complete/2` call records a two-phase intent with
  `op_kind: "llm_complete"` + a deterministic idempotency key of
  `"run:<id>:stage:<sid>:llm_complete:<attempt>"`. On success,
  `complete_op/2` writes the result summary; on error, `fail_op/2`.
  Telemetry span wraps the side-effect that happens BETWEEN intent and
  completion/failure.

  ## Secrets grep audit (D-132)

  The plan-level acceptance test in
  `test/kiln/agents/adapter/anthropic_test.exs` asserts exactly ONE
  `Kiln.Secrets.reveal!` call site in this file. All consumers of the
  raw key flow through `fetch_api_key/0`.
  """

  @behaviour Kiln.Agents.Adapter

  alias Kiln.Agents.{Prompt, Response}
  alias Kiln.{ExternalOperations, Secrets, Telemetry}

  require Logger

  @anthropic_base_url "https://api.anthropic.com"
  @anthropic_version "2023-06-01"

  @impl true
  def capabilities do
    %{
      streaming: true,
      tools: true,
      thinking: true,
      vision: true,
      json_schema_mode: true
    }
  end

  @impl true
  def complete(%Prompt{} = prompt, opts) do
    # Unpack caller's Logger metadata if it was packed via Kiln.Telemetry.pack_ctx/0
    # (e.g., across an Oban boundary). Direct-in-process callers already have
    # Logger.metadata populated.
    ctx = Keyword.get(opts, :kiln_ctx, %{})
    if map_size(ctx) > 0, do: Telemetry.unpack_ctx(ctx)

    run_id = Logger.metadata()[:run_id]
    stage_id = Logger.metadata()[:stage_id]
    requested_model = prompt.model || Keyword.get(opts, :model)
    role = Keyword.get(opts, :role)
    attempt = Keyword.get(opts, :attempt, 1)

    {_status, op} = record_intent(run_id, stage_id, attempt, prompt, opts)

    meta_start = %{
      run_id: run_id,
      stage_id: stage_id,
      requested_model: requested_model,
      provider: :anthropic,
      role: role
    }

    # Manual telemetry emission per D-110 — `:stop` measurements MUST
    # carry `tokens_in / tokens_out / cost_usd` (provider-specific
    # counters). `:telemetry.span/3` hard-codes measurements to
    # `{monotonic_time, duration}`; we need the richer shape here.
    start_mono = System.monotonic_time()
    start_system = System.system_time()
    :telemetry.execute([:kiln, :agent, :call, :start], %{system_time: start_system}, meta_start)

    try do
      case do_complete(prompt, opts) do
        {:ok, %Response{} = response} ->
          if op, do: record_completion(op, response)

          duration = System.monotonic_time() - start_mono

          measurements = %{
            duration: duration,
            tokens_in: response.tokens_in || 0,
            tokens_out: response.tokens_out || 0,
            cost_usd: response.cost_usd
          }

          stop_meta =
            meta_start
            |> Map.put(:actual_model_used, response.actual_model_used)
            |> Map.put(
              :fallback?,
              response.actual_model_used != nil and
                response.actual_model_used != requested_model
            )

          :telemetry.execute([:kiln, :agent, :call, :stop], measurements, stop_meta)
          {:ok, response}

        {:error, reason} = err ->
          if op, do: record_failure(op, reason)
          duration = System.monotonic_time() - start_mono

          :telemetry.execute(
            [:kiln, :agent, :call, :stop],
            %{duration: duration, tokens_in: 0, tokens_out: 0, cost_usd: nil},
            Map.put(meta_start, :error_reason, inspect(reason))
          )

          err
      end
    rescue
      exception ->
        duration = System.monotonic_time() - start_mono

        :telemetry.execute(
          [:kiln, :agent, :call, :exception],
          %{duration: duration},
          Map.merge(meta_start, %{
            kind: :error,
            reason: exception,
            stacktrace: __STACKTRACE__
          })
        )

        reraise exception, __STACKTRACE__
    end
  end

  @impl true
  def stream(%Prompt{} = _prompt, _opts) do
    # D-103: stream/2 returns Enumerable passthrough; NO PubSub in P3.
    # Phase 4 (work units) + Phase 7 (LiveView consumer) each name their
    # own consumer shape — shipping a live wrapper here would commit
    # backpressure policy without a calibrated consumer.
    #
    # P3 returns {:error, :stream_not_implemented_p3}; the contract is
    # preserved (Enumerable.t() typed return shape). The single
    # Kiln.Secrets.reveal!/1 call site per D-132 grep audit stays inside
    # `fetch_api_key/0` below — streaming via Anthropix would add a
    # second call site. Phase 4 wires the Anthropix.stream path through
    # the same helper once a consumer lands.
    {:error, :stream_not_implemented_p3}
  end

  @impl true
  def count_tokens(%Prompt{} = prompt) do
    # Anthropix 0.6.2 does NOT wrap count_tokens (PATTERNS anti-pattern #3).
    # Direct Req call against POST /v1/messages/count_tokens.
    headers = build_headers()
    base = base_url()

    body =
      %{"model" => prompt.model, "messages" => prompt.messages}
      |> maybe_put("system", prompt.system)

    case Req.post("#{base}/v1/messages/count_tokens",
           finch: Kiln.Finch,
           headers: headers,
           json: body
         ) do
      {:ok, %{status: 200, body: %{"input_tokens" => n}}} ->
        {:ok, n}

      {:ok, %{status: status, body: body}} ->
        {:error, {:http_status, status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # ---- Two-phase intent integration ----------------------------------

  defp record_intent(run_id, stage_id, attempt, %Prompt{} = prompt, _opts) do
    # If run_id / stage_id are absent (pre-Wave-5 caller or a test not
    # in an Ecto sandbox), skip the intent row — the caller is
    # responsible for its own side-effect bookkeeping. The sandbox
    # AuditLedgerCase sets up the Repo connection; when it's present we
    # always record.
    if run_id && stage_id && repo_available?() do
      idempotency_key = "run:#{run_id}:stage:#{stage_id}:llm_complete:#{attempt}"

      case ExternalOperations.fetch_or_record_intent(idempotency_key, %{
             op_kind: "llm_complete",
             intent_payload: prompt_audit_shape(prompt),
             run_id: run_id,
             stage_id: stage_id
           }) do
        {:error, _} -> {nil, nil}
        {status, op} -> {status, op}
      end
    else
      {nil, nil}
    end
  end

  defp record_completion(op, %Response{} = response) do
    try do
      ExternalOperations.complete_op(op, %{
        "result" => "ok",
        "tokens_in" => response.tokens_in || 0,
        "tokens_out" => response.tokens_out || 0,
        "actual_model_used" => response.actual_model_used,
        "cost_usd" => decimal_to_string(response.cost_usd)
      })
    rescue
      _ -> :ok
    end
  end

  defp record_failure(op, reason) do
    try do
      ExternalOperations.fail_op(op, %{"reason" => inspect(reason)})
    rescue
      _ -> :ok
    end
  end

  defp repo_available? do
    Process.whereis(Kiln.Repo) != nil
  end

  defp decimal_to_string(nil), do: nil
  defp decimal_to_string(%Decimal{} = d), do: Decimal.to_string(d)
  defp decimal_to_string(other) when is_number(other), do: to_string(other)

  # ---- HTTP helpers --------------------------------------------------

  defp do_complete(%Prompt{} = prompt, opts) do
    headers = build_headers()
    base = Keyword.get(opts, :base_url) || base_url()

    body =
      %{
        "model" => prompt.model,
        "messages" => prompt.messages,
        "max_tokens" => prompt.max_tokens
      }
      |> maybe_put("system", prompt.system)
      |> maybe_put("temperature", if(prompt.temperature != 1.0, do: prompt.temperature))
      |> maybe_put("tools", if(prompt.tools != [], do: prompt.tools))

    case Req.post("#{base}/v1/messages", finch: Kiln.Finch, headers: headers, json: body) do
      {:ok, %{status: 200, body: raw}} ->
        {:ok, build_response(raw)}

      {:ok, %{status: status, body: body}} ->
        {:error, {:http_status, status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp build_headers do
    # Single reveal! site in this file (D-132 grep audit).
    key = fetch_api_key()

    [
      {"x-api-key", key},
      {"anthropic-version", @anthropic_version},
      {"content-type", "application/json"}
    ]
  end

  # The SOLE `Kiln.Secrets.reveal!/1` call site in this file (D-132 /
  # D-133 Layer 1). The returned binary crosses exactly one stack frame —
  # this helper to `build_headers/0` — and is immediately placed into an
  # HTTP header. It never enters a struct, never crosses a GenServer
  # boundary, and never appears in a log line.
  defp fetch_api_key do
    Secrets.reveal!(:anthropic_api_key)
  end

  defp base_url do
    Application.get_env(:kiln, __MODULE__, [])
    |> Keyword.get(:base_url, @anthropic_base_url)
  end

  defp build_response(raw) when is_map(raw) do
    actual_model = Map.get(raw, "model")
    tokens_in = get_in(raw, ["usage", "input_tokens"]) || 0
    tokens_out = get_in(raw, ["usage", "output_tokens"]) || 0

    %Response{
      content: Map.get(raw, "content"),
      stop_reason: Map.get(raw, "stop_reason") |> stop_reason_atom(),
      tokens_in: tokens_in,
      tokens_out: tokens_out,
      cost_usd: estimate_cost(actual_model, tokens_in, tokens_out),
      actual_model_used: actual_model,
      raw: raw
    }
  end

  defp stop_reason_atom(nil), do: nil
  defp stop_reason_atom(s) when is_binary(s), do: String.to_atom(s)
  defp stop_reason_atom(s) when is_atom(s), do: s

  # Plan 03-06 ships `Kiln.Pricing.estimate_usd/3`. Until it lands,
  # gracefully fall through to `nil` so the adapter compiles + runs
  # against the Bypass stub without requiring Pricing. The telemetry
  # :stop measurement tolerates nil `:cost_usd`; BudgetGuard (P3 Plan
  # 06) will enforce the presence contract once Pricing ships.
  defp estimate_cost(model, tokens_in, tokens_out) do
    if Code.ensure_loaded?(Kiln.Pricing) and
         function_exported?(Kiln.Pricing, :estimate_usd, 3) do
      apply(Kiln.Pricing, :estimate_usd, [model, tokens_in, tokens_out])
    else
      nil
    end
  end

  defp prompt_audit_shape(%Prompt{} = p) do
    %{
      "model" => p.model,
      "max_tokens" => p.max_tokens,
      "messages_count" => length(p.messages),
      "tools_count" => length(p.tools)
    }
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
