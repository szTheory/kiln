defmodule Kiln.Telemetry.MetadataThreadingTest do
  @moduledoc """
  D-47 / Phase 1 Success Criterion #3 — the contrived multi-process
  proof that metadata threads across `Task.async_stream` AND Oban job
  boundaries.

  This test is the load-bearing mechanical proof that OBS-01 is true,
  not a vibes-based claim. Three scenarios:

    * LOG-01 — a `Kiln.Telemetry.async_stream/3` child inherits the
      parent's `correlation_id` without explicit threading at the call
      site (covered by the wrapper's closure pre-packing).
    * LOG-02 — an Oban worker's `perform/1` inherits the enqueueing
      caller's `correlation_id` via the `[:oban, :job, :start]`
      telemetry handler that unpacks `job.meta["kiln_ctx"]`.
    * D-47 combined — both paths in one test run, both carry the same
      parent correlation_id.

  `async: false` because the tests attach `:logger` handlers (global
  BEAM state) and mutate `Logger.metadata` across process boundaries.
  """
  use ExUnit.Case, async: false
  use Oban.Testing, repo: Kiln.Repo

  import Kiln.LoggerCaptureHelper
  require Logger

  alias Kiln.Telemetry
  alias Kiln.Telemetry.ObanHandler

  defmodule ProbeWorker do
    @moduledoc false

    # Vanilla Oban.Worker (NOT Kiln.Oban.BaseWorker — that lands in
    # Plan 01-04, which builds on top of the metadata-threading
    # plumbing this plan establishes).
    use Oban.Worker, queue: :default, max_attempts: 1

    require Logger

    @impl Oban.Worker
    def perform(%Oban.Job{args: %{"probe" => probe_id}}) do
      Logger.info("probe_oban_worker running probe=#{probe_id}")
      :ok
    end
  end

  setup do
    # Attach the Oban telemetry handler explicitly for each test. In
    # production, `Kiln.Application.start/2` attaches it at boot — but
    # the test env sometimes starts multiple OTP apps with their own
    # lifecycles, and a previous test's :detach could leave the
    # handler missing. Re-attach defensively and tolerate the "already
    # exists" error that fires when the app-level attach ran first.
    _ = ObanHandler.attach()

    # Wipe per-process metadata to avoid leakage from earlier tests
    # (ExUnit runs tests in the same OS process; Logger.metadata is
    # process-dict-backed).
    Logger.reset_metadata([])
    :ok
  end

  describe "LOG-01: Task.async_stream child carries parent's correlation_id" do
    test "each child log line has the parent's correlation_id" do
      parent_cid = Ecto.UUID.generate()

      {_result, lines} =
        capture_json(fn ->
          Logger.metadata(correlation_id: parent_cid, run_id: "parent_run")
          Logger.info("parent_line_lo1")

          [1, 2, 3]
          |> Telemetry.async_stream(fn i ->
            # Inside a Task child process — fresh Logger.metadata by
            # default; the wrapper unpacks parent ctx before this fn
            # body runs.
            Logger.info("child_line_lo1 i=#{i}")
            i * 2
          end)
          |> Enum.to_list()
        end)

      child_lines = Enum.filter(lines, &String.contains?(get_message(&1), "child_line_lo1"))

      child_count = Enum.count(child_lines)

      assert child_count == 3,
             "expected 3 async_stream child log lines, got #{child_count} (lines=#{inspect(lines)})"

      for line <- child_lines do
        assert get_metadata(line, "correlation_id") == parent_cid,
               "child line missing or wrong correlation_id: #{inspect(line)}"

        assert get_metadata(line, "run_id") == "parent_run",
               "child line missing or wrong run_id: #{inspect(line)}"
      end
    end
  end

  describe "LOG-02: Oban worker inherits enqueueing process's correlation_id" do
    test "perform/1 log line carries the enqueue-time correlation_id" do
      parent_cid = Ecto.UUID.generate()
      probe = "lo2_#{System.unique_integer([:positive])}"

      {_result, lines} =
        capture_json(fn ->
          # Enqueue-time — pack current metadata into job meta
          Logger.metadata(correlation_id: parent_cid, run_id: "parent_run_lo2")

          job = build_job(ProbeWorker, %{"probe" => probe}, meta: Telemetry.pack_meta())

          # Clear the test process's metadata BEFORE perform_job. This
          # proves the ObanHandler restored ctx (otherwise the test
          # process's own metadata would carry the values and we'd be
          # measuring that, not the handler).
          Logger.reset_metadata([])

          assert :ok = perform_job(job, [])
        end)

      worker_lines = Enum.filter(lines, &String.contains?(get_message(&1), probe))

      assert worker_lines != [],
             "no log line matched probe=#{probe}; lines=#{inspect(lines)}"

      for line <- worker_lines do
        assert get_metadata(line, "correlation_id") == parent_cid,
               "Oban worker log line missing or wrong correlation_id: #{inspect(line)}"

        assert get_metadata(line, "run_id") == "parent_run_lo2",
               "Oban worker log line missing or wrong run_id: #{inspect(line)}"
      end
    end
  end

  describe "D-47 combined: Task.async_stream + Oban job BOTH carry parent correlation_id" do
    test "both paths exercised in the same run produce matching correlation_ids" do
      parent_cid = Ecto.UUID.generate()
      probe = "combo_#{System.unique_integer([:positive])}"

      {_, lines} =
        capture_json(fn ->
          Logger.metadata(correlation_id: parent_cid, run_id: "combo_run")

          # Path 1: Task.async_stream — children get ctx via wrapper
          task_work =
            [:a, :b]
            |> Telemetry.async_stream(fn letter ->
              Logger.info("async_stream letter=#{letter}")
              letter
            end)
            |> Enum.to_list()

          # Path 2: Oban job — worker gets ctx via pack_meta + ObanHandler.
          # Pack meta BEFORE clearing parent metadata.
          job = build_job(ProbeWorker, %{"probe" => probe}, meta: Telemetry.pack_meta())

          # Clear parent metadata to prove ObanHandler restored it.
          Logger.reset_metadata([])

          assert :ok = perform_job(job, [])

          task_work
        end)

      async_lines = Enum.filter(lines, &String.contains?(get_message(&1), "async_stream"))
      oban_lines = Enum.filter(lines, &String.contains?(get_message(&1), probe))

      assert async_lines != [], "async_stream produced no log lines; all lines=#{inspect(lines)}"
      assert oban_lines != [], "Oban worker produced no log lines; all lines=#{inspect(lines)}"

      for line <- async_lines ++ oban_lines do
        assert get_metadata(line, "correlation_id") == parent_cid,
               "mismatched correlation_id on line: #{inspect(line)}"
      end
    end
  end

  # JSON shape helpers — LoggerJSON.Formatters.Basic nests whitelisted
  # metadata under a top-level "metadata" object.
  defp get_metadata(line, key), do: line["metadata"][key] || line[key]
  defp get_message(line), do: line["message"] || ""
end
