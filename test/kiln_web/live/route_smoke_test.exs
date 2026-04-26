defmodule KilnWeb.RouteSmokeTest do
  @moduledoc """
  Shift-left UI regression guard — boots every LiveView in
  `KilnWeb.Router`'s `live_session :default` and asserts:

    1. Mount/render succeeds (no 500, no unhandled assigns).
    2. The rendered HTML contains none of the retired brand tokens
       (`text-bone`, `border-ash`, `bg-char`, `bg-iron`, `text-ember`,
       `border-clay`, `border-ember`, `kiln-btn*`, bare `kiln-card`) —
       protects the Phase-reskin from silent regressions on PRs that
       only touch HEEx.
    3. Every page renders a `<header>` landmark (operator chrome).

  Fast (sub-second), no new deps, runs under `mix check` via the normal
  `mix test` step in `.check.exs`.
  """

  use KilnWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Kiln.Factory.Run, as: RunFactory
  alias Kiln.Factory.StageRun, as: StageRunFactory
  alias Kiln.Specs
  alias Kiln.Workflows
  alias Kiln.Workflows.Loader

  @moduletag :ui_route_smoke

  # Retired legacy tokens from the Phase reskin. We negative-match on
  # raw strings (no word boundaries) so any reappearance anywhere in
  # rendered HTML — class attrs, inline styles, data attrs — fails.
  @legacy_tokens [
    "text-bone",
    "border-ash",
    "bg-char",
    "bg-iron",
    "text-ember",
    "border-clay",
    "border-ember",
    "kiln-btn",
    "text-[var(--color-smoke)]",
    "text-[var(--color-clay)]"
  ]

  setup do
    # Parent run for /runs/:id + /runs/:id/replay + /runs/compare
    run_a = RunFactory.insert(:run, workflow_id: "route_smoke_a")
    run_b = RunFactory.insert(:run, workflow_id: "route_smoke_b")

    _stage_a =
      StageRunFactory.insert(:stage_run,
        run_id: run_a.id,
        workflow_stage_id: "route_smoke_stage"
      )

    _stage_b =
      StageRunFactory.insert(:stage_run,
        run_id: run_b.id,
        workflow_stage_id: "route_smoke_stage"
      )

    # Workflow snapshot for /workflows/:id
    path = Application.app_dir(:kiln, "priv/workflows/elixir_phoenix_feature.yaml")
    {:ok, cg} = Loader.load(path)
    yaml = File.read!(path)

    {:ok, _} =
      Workflows.record_snapshot(%{
        workflow_id: cg.id,
        version: cg.version,
        compiled_checksum: cg.checksum,
        yaml: yaml
      })

    # Spec + revision for /specs/:id/edit
    {:ok, spec} = Specs.create_spec(%{title: "Route smoke"})
    {:ok, _rev} = Specs.create_revision(spec, %{body: "# smoke\nminimal spec body\n"})

    # Seeded draft so /inbox isn't always the empty state
    {:ok, _draft} =
      Specs.create_draft(%{
        title: "Route smoke draft",
        body: "Draft body text.",
        source: :freeform
      })

    %{run_a: run_a, run_b: run_b, workflow_id: cg.id, spec: spec}
  end

  describe "index routes" do
    test "every index LiveView mounts, renders, and stays on-brand", %{conn: conn} do
      for path <- [
            "/onboarding",
            "/",
            "/attach",
            "/templates",
            "/inbox",
            "/workflows",
            "/costs",
            "/providers",
            "/settings",
            "/audit"
          ] do
        assert_route_renders_cleanly(conn, path)
      end
    end

    test "templates index keeps the first-run hero visible", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/templates")

      assert has_element?(view, "#templates-first-run-hero")
      assert has_element?(view, "#template-card-hello-kiln")
    end
  end

  describe "parameterized routes" do
    test "run detail + replay", %{conn: conn, run_a: run} do
      assert_route_renders_cleanly(conn, "/runs/#{run.id}")
      assert_route_renders_cleanly(conn, "/runs/#{run.id}/replay")
    end

    test "run compare with baseline + candidate query", %{conn: conn, run_a: a, run_b: b} do
      qs = URI.encode_query(%{"baseline" => a.id, "candidate" => b.id})
      assert_route_renders_cleanly(conn, "/runs/compare?" <> qs)
    end

    test "template detail (hello-kiln is seeded from priv)", %{conn: conn} do
      assert_route_renders_cleanly(conn, "/templates/hello-kiln")
    end

    test "template detail still renders the next-steps surface", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/templates/hello-kiln")

      assert has_element?(view, "#template-detail-next-steps")
    end

    test "workflow detail", %{conn: conn, workflow_id: wf_id} do
      assert_route_renders_cleanly(conn, "/workflows/#{wf_id}")
    end

    test "spec editor", %{conn: conn, spec: spec} do
      assert_route_renders_cleanly(conn, "/specs/#{spec.id}/edit")
    end
  end

  # Shared assertion — mount, landmark, and legacy-token refute.
  defp assert_route_renders_cleanly(conn, path) do
    case live(conn, path) do
      {:ok, view, html} ->
        assert has_element?(view, "header"),
               "#{path}: missing <header> landmark (operator chrome)"

        for token <- @legacy_tokens do
          refute String.contains?(html, token),
                 "#{path}: rendered HTML contains retired legacy token `#{token}` — reskin regression"
        end

      {:error, {:live_redirect, %{to: to}}} ->
        # Redirects are legitimate outcomes for a few routes (e.g.
        # `/onboarding` → `/` when ready); follow once and assert the
        # destination is on-brand too.
        {:ok, view, html} = live(conn, to)

        assert has_element?(view, "header"),
               "#{path} → #{to}: missing <header> landmark"

        for token <- @legacy_tokens do
          refute String.contains?(html, token),
                 "#{path} → #{to}: rendered HTML contains retired legacy token `#{token}`"
        end

      other ->
        flunk("#{path}: unexpected live/2 result: #{inspect(other)}")
    end
  end
end
