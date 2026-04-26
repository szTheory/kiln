defmodule Kiln.Notifications do
  @moduledoc """
  Desktop notifications via `osascript` (macOS) / `notify-send` (Linux),
  dispatched synchronously from typed-block raise sites (D-140 / BLOCK-03).

  **Key invariants:**

    * OS detection uses `:os.type/0` at RUNTIME. Reading compile-time
      environment at runtime is the anti-pattern called out in
      CLAUDE.md P15 — never used here.
    * `:osascript_notify` external_operations intent row is inserted for
      every fire path so the two-phase `intent → action → completion`
      machine (D-14..D-18) covers notification dispatch the same way it
      covers LLM calls and Docker runs.
    * ETS-backed dedup via `Kiln.Notifications.DedupCache`: key is
      `{run_id, reason}`, TTL 5 minutes. Identical key within TTL is
      silently dropped; audit kind `notification_fired` vs
      `notification_suppressed` recorded either way.
    * Reason atom is validated against `Kiln.Blockers.Reason.valid?/1`
      BEFORE shell-out — unknown reasons return
      `{:error, :invalid_reason}` (T-03-04-02 mitigation).

  **Platform behaviour:**

    * `{:unix, :darwin}` → `System.cmd("osascript", ["-e", applescript], ...)`
      where `applescript` is built as
      `"display notification <body> with title <title>"`. Body and
      title are `inspect/1`-wrapped so Elixir's quote-escaping covers
      shell injection from context-map values (T-03-04-01).
    * `{:unix, :linux}` → `System.cmd("notify-send", [flags..., title,
      body], ...)`. Args are passed as a list (no shell expansion) and
      the `-h string:x-canonical-private-synchronous:<tag>` header
      enables Linux's native last-write-wins dedup.
    * Any other `:os.type/0` → `{:error, :unsupported_platform}` plus a
      `notification_suppressed` audit event with a
      `ttl_remaining_seconds: 0` payload so operator traces the dropped
      surface.

  **Integration with `Kiln.Blockers`:**

  Every `Kiln.Blockers.raise_block/3` caller in Phase 3+ also calls
  `Kiln.Notifications.desktop/2` with the same `reason` + a `run_id` /
  `provider` / `severity` context map. The notification body is
  rendered via `Kiln.Blockers.render/2` — the same remediation text the
  operator sees on the Unblock Panel (Phase 8).
  """

  require Logger

  alias Kiln.Audit
  alias Kiln.Blockers
  alias Kiln.ExternalOperations
  alias Kiln.Notifications.DedupCache

  @doc """
  Dispatch a desktop notification for the given typed block `reason`.

  Returns `:ok` on successful dispatch or on successful suppression
  (within-TTL dedup); `{:error, reason}` on unknown reason, platform
  unsupported, or shell-out failure.

  `ctx` is a map that MUST contain `:run_id` (may be `nil`) and SHOULD
  contain `:provider`, `:severity`, and any other `{var}` tokens the
  playbook for `reason` references. Unknown tokens are preserved as
  literals by `Kiln.Blockers.render/2`.
  """
  @spec desktop(atom(), map()) :: :ok | {:error, term()}
  def desktop(reason, ctx) when is_atom(reason) and is_map(ctx) do
    if not Blockers.Reason.valid?(reason) do
      Logger.error("Kiln.Notifications.desktop/2 received invalid reason: " <> inspect(reason))

      {:error, :invalid_reason}
    else
      run_id = Map.get(ctx, :run_id)
      key = {run_id, reason}

      case DedupCache.check_and_record(key) do
        :fire ->
          do_dispatch(reason, run_id, ctx, key)

        :suppress ->
          audit_suppressed(reason, run_id, key)
          :ok
      end
    end
  end

  defp do_dispatch(reason, run_id, ctx, key) do
    correlation_id = Logger.metadata()[:correlation_id] || Ecto.UUID.generate()

    # Two-phase intent — D-14..D-18. Idempotency key is
    # deterministic-per-dispatch (millisecond granularity + reason +
    # run_id) so a retry within the same millisecond observes the
    # existing row and doesn't double-shell-out.
    idempotency_key =
      "notify:#{run_id_segment(run_id)}:#{reason}:#{System.system_time(:millisecond)}"

    case ExternalOperations.fetch_or_record_intent(idempotency_key, %{
           op_kind: "osascript_notify",
           intent_payload: %{
             "reason" => Atom.to_string(reason),
             "run_id" => run_id
           },
           run_id: run_id,
           correlation_id: correlation_id
         }) do
      {_status, op} when is_struct(op) ->
        do_dispatch_with_intent(op, reason, run_id, ctx, key, correlation_id)

      {:error, err} ->
        Logger.error(
          "Kiln.Notifications: failed to record intent for " <>
            "reason=#{reason} run_id=#{inspect(run_id)}: #{inspect(err)}"
        )

        {:error, {:intent_record_failed, err}}
    end
  end

  defp do_dispatch_with_intent(op, reason, run_id, ctx, key, correlation_id) do
    {platform, dispatch_result} = dispatch_platform(reason, ctx)

    case dispatch_result do
      :ok ->
        _ =
          ExternalOperations.complete_op(op, %{
            "result" => "fired",
            "platform" => Atom.to_string(platform)
          })

        audit_fired(reason, run_id, key, platform, correlation_id)
        :ok

      {:error, err} = err_tuple ->
        _ =
          ExternalOperations.fail_op(op, %{
            "reason" => inspect(err),
            "platform" => Atom.to_string(platform)
          })

        # On unsupported platform, still emit a suppressed audit event so
        # the operator's trace shows "we would have notified here."
        if platform == :unsupported do
          audit_suppressed_unsupported(reason, run_id, key, correlation_id)
        else
          Logger.error("Kiln.Notifications dispatch failed on #{platform}: #{inspect(err)}")
        end

        err_tuple
    end
  end

  # ---- Platform dispatch (System.cmd shell-out) ---------------------------

  defp dispatch_platform(reason, ctx) do
    body = format_body(reason, ctx)
    title = format_title(ctx)

    case :os.type() do
      {:unix, :darwin} ->
        # `inspect/1` on binaries produces a quoted Elixir string which
        # in turn is a valid AppleScript double-quoted string literal.
        # Any quote/backslash in the body is escape-safe (T-03-04-01).
        applescript =
          "display notification #{inspect(body)} with title #{inspect(title)}"

        case System.cmd("osascript", ["-e", applescript], stderr_to_stdout: true) do
          {_out, 0} -> {:macos, :ok}
          {err, code} -> {:macos, {:error, {code, err}}}
        end

      {:unix, :linux} ->
        # Linux-native last-write-wins dedup via the
        # x-canonical-private-synchronous hint header — complementary to
        # our ETS dedup (ETS catches storms inside 5-min window; this
        # header coalesces notifications fired back-to-back in the same
        # X session before the notifier daemon dismisses the first one).
        tag = "x-canonical-private-synchronous:#{tag_suffix(ctx, reason)}"

        args = [
          "-u",
          "critical",
          "-c",
          "kiln",
          "-h",
          "string:" <> tag,
          title,
          body
        ]

        try do
          case System.cmd("notify-send", args, stderr_to_stdout: true) do
            {_out, 0} -> {:linux, :ok}
            {err, code} -> {:linux, {:error, {code, err}}}
          end
        rescue
          e in ErlangError ->
            if e.original == :enoent do
              {:linux, {:error, :notify_send_not_found}}
            else
              reraise e, __STACKTRACE__
            end
        end

      other ->
        {:unsupported, {:error, {:unsupported_platform, other}}}
    end
  end

  defp format_body(reason, ctx) do
    short =
      case Blockers.render(reason, ctx) do
        {:ok, rendered} -> rendered.short_message
        _ -> Atom.to_string(reason)
      end

    run_line =
      case Map.get(ctx, :run_id) do
        nil -> ""
        run_id -> "\nrun: #{inspect(run_id)}"
      end

    short <> run_line
  end

  defp format_title(ctx) do
    severity = ctx[:severity] || "halt"
    "Kiln — #{severity}"
  end

  defp tag_suffix(ctx, reason) do
    run_id_segment(Map.get(ctx, :run_id)) <> "_" <> Atom.to_string(reason)
  end

  defp run_id_segment(nil), do: "no-run"
  defp run_id_segment(run_id), do: to_string(run_id)

  # ---- Audit event emission ----------------------------------------------

  defp audit_fired(reason, run_id, {_, _} = key, platform, correlation_id) do
    _ =
      Audit.append(%{
        event_kind: :notification_fired,
        run_id: run_id,
        correlation_id: correlation_id,
        payload: %{
          "reason" => Atom.to_string(reason),
          "platform" => Atom.to_string(platform),
          "dedup_key" => inspect(key),
          "run_id" => run_id
        }
      })

    :ok
  end

  defp audit_suppressed(reason, run_id, {_, _} = key) do
    correlation_id = Logger.metadata()[:correlation_id] || Ecto.UUID.generate()

    _ =
      Audit.append(%{
        event_kind: :notification_suppressed,
        run_id: run_id,
        correlation_id: correlation_id,
        payload: %{
          "reason" => Atom.to_string(reason),
          "dedup_key" => inspect(key),
          "run_id" => run_id,
          "ttl_remaining_seconds" => 0
        }
      })

    :ok
  end

  defp audit_suppressed_unsupported(reason, run_id, {_, _} = key, correlation_id) do
    _ =
      Audit.append(%{
        event_kind: :notification_suppressed,
        run_id: run_id,
        correlation_id: correlation_id,
        payload: %{
          "reason" => Atom.to_string(reason),
          "dedup_key" => inspect(key),
          "run_id" => run_id,
          "ttl_remaining_seconds" => 0
        }
      })

    :ok
  end
end
