defmodule KilnWeb.ProviderHealthLiveTest do
  @moduledoc false
  use KilnWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Kiln.ModelRegistry

  setup do
    _ = ModelRegistry.provider_health_snapshots()
    tid = :kiln_provider_health_counters

    if :ets.whereis(tid) != :undefined do
      :ets.delete_all_objects(tid)
    end

    for id <- [:anthropic, :openai, :google, :ollama] do
      :ets.insert(tid, {id, %{oks: 0, errors: 0, last_ok_at: nil, rate_limit_remaining: nil}})
    end

    :ok
  end

  test "GET /providers renders provider-health and a status label", %{conn: conn} do
    {:ok, view, html} = live(conn, ~p"/providers")

    assert html =~ ~s(id="provider-health")
    assert has_element?(view, "#provider-health")
    html2 = render(view)
    assert html2 =~ "Operational" or html2 =~ "API key missing"
  end

  test "poll tick refreshes cards when error counters move into degraded range", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/providers")
    html_before = render(view)
    refute html_before =~ "Degraded"

    for _ <- 1..5 do
      _ = ModelRegistry.provider_health_record_error(:anthropic)
    end

    send(view.pid, :tick)
    html_after = render(view)
    assert html_after =~ "Degraded"
  end
end
