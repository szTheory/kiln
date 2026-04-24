defmodule KilnWeb.RunBoardLiveTest do
  use KilnWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Kiln.Factory.Run, as: RunFactory
  alias Kiln.OperatorReadiness
  alias Kiln.Repo
  alias Kiln.Runs.Run
  alias Kiln.Stages.StageRun

  setup do
    prior = Application.get_env(:kiln, :operator_runtime_mode)

    on_exit(fn ->
      if prior == nil do
        Application.delete_env(:kiln, :operator_runtime_mode)
      else
        Application.put_env(:kiln, :operator_runtime_mode, prior, persistent: false)
      end
    end)

    assert {:ok, _} = OperatorReadiness.mark_step(:anthropic, true)
    assert {:ok, _} = OperatorReadiness.mark_step(:github, true)
    assert {:ok, _} = OperatorReadiness.mark_step(:docker, true)

    :ok
  end

  describe "GET /" do
    test "renders run board shell and empty state", %{conn: conn} do
      Repo.delete_all(StageRun)
      Repo.delete_all(Run)
      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, "#run-board")
      assert render(view) =~ "No runs in flight"
      assert has_element?(view, "#run-board-overview")
      assert render(view) =~ "The fastest first path is setup, then templates"
    end

    test "shows live-mode disconnected hero when setup is incomplete", %{conn: conn} do
      Application.put_env(:kiln, :operator_runtime_mode, :live, persistent: false)
      assert {:ok, _} = OperatorReadiness.mark_step(:docker, false)

      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, "#run-board-live-hero")
      assert render(view) =~ "Open settings checklist"
    end

    test "renders factory chrome: header, run progress, agent ticker stream", %{conn: conn} do
      _ =
        RunFactory.insert(:run,
          state: :coding,
          workflow_id: "wf-chrome"
        )

      {:ok, view, _html} = live(conn, ~p"/")
      html = render(view)

      assert html =~ ~s(id="factory-header")
      assert html =~ ~s(id="agent-ticker")
      assert html =~ ~s(id="run-board-watch")
      assert html =~ ~s(id="run-board-attention")
      assert html =~ "wf-chrome"
      assert html =~ "Stages"
      assert html =~ "State Coding"

      Phoenix.PubSub.broadcast(
        Kiln.PubSub,
        "agent_ticker",
        {:agent_ticker_line, %{run_id: "x", stage_id: "coding", line: "hello ticker"}}
      )

      assert render(view) =~ "hello ticker"
    end

    test "renders kanban cards and updates on runs:board PubSub", %{conn: conn} do
      run =
        RunFactory.insert(:run,
          state: :coding,
          workflow_id: "wf-pubsub-board"
        )

      {:ok, view, _html} = live(conn, ~p"/")
      html = render(view)
      assert html =~ "wf-pubsub-board"
      assert html =~ "data-state=\"coding\""
      assert html =~ "Inspect"

      updated = %{run | state: :testing, updated_at: DateTime.utc_now(:microsecond)}
      Phoenix.PubSub.broadcast(Kiln.PubSub, "runs:board", {:run_state, updated})
      _ = render(view)

      html2 = render(view)
      assert html2 =~ "wf-pubsub-board"
      assert html2 =~ "data-state=\"testing\""
    end
  end
end
