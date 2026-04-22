defmodule KilnWeb.RunCompareLiveTest do
  use KilnWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Kiln.Factory.Run, as: RunFactory
  alias Kiln.Factory.StageRun, as: StageRunFactory

  describe "GET /runs/compare" do
    test "happy path renders compare chrome and data attributes", %{conn: conn} do
      a = RunFactory.insert(:run, workflow_id: "elixir_phoenix_feature")
      b = RunFactory.insert(:run, workflow_id: "elixir_phoenix_feature")

      _ =
        StageRunFactory.insert(:stage_run,
          run_id: a.id,
          workflow_stage_id: "cmp_stage",
          attempt: 1
        )

      _ =
        StageRunFactory.insert(:stage_run,
          run_id: b.id,
          workflow_stage_id: "cmp_stage",
          attempt: 1
        )

      bl = canonical_uuid_string(a.id)
      ca = canonical_uuid_string(b.id)

      path = "/runs/compare?" <> URI.encode_query(%{"baseline" => bl, "candidate" => ca})
      {:ok, view, _html} = live(conn, path)

      html = render(view)

      assert has_element?(view, "#run-compare")
      assert html =~ "data-baseline-id=\"#{bl}\""
      assert html =~ "data-candidate-id=\"#{ca}\""
      assert html =~ "data-stage-key=\"cmp_stage\""
    end

    test "invalid baseline uuid redirects home", %{conn: conn} do
      b = RunFactory.insert(:run)
      cand = canonical_uuid_string(b.id)

      path =
        "/runs/compare?" <>
          URI.encode_query(%{"baseline" => "not-a-uuid", "candidate" => cand})

      assert {:error, {:live_redirect, %{to: "/"}}} = live(conn, path)
    end
  end

  defp canonical_uuid_string(id) do
    case Ecto.UUID.cast(id) do
      {:ok, bin} when byte_size(bin) == 16 ->
        h = Base.encode16(bin, case: :lower)

        String.slice(h, 0, 8) <>
          "-" <>
          String.slice(h, 8, 4) <>
          "-" <>
          String.slice(h, 12, 4) <>
          "-" <>
          String.slice(h, 16, 4) <>
          "-" <>
          String.slice(h, 20, 12)

      _ ->
        to_string(id)
    end
  end
end
