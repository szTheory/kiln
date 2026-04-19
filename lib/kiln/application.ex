defmodule Kiln.Application do
  @moduledoc false
  use Application

  alias Kiln.Telemetry.ObanHandler

  # D-42 locks the children list to EXACTLY 7 — no DNSCluster, no stub
  # Phase 2+ children. Plan 06 re-topologises into a staged start
  # (infra children → BootChecks.run! → Endpoint) so a violated
  # invariant halts the BEAM BEFORE the endpoint binds a port — the
  # probe URL simply refuses connection, which is the correct signal
  # for "dead factory". Post-boot the supervisor still has EXACTLY
  # the 7 D-42 children.
  @impl true
  def start(_type, _args) do
    # Stage 1: start the 6 infra children BootChecks needs (Repo +
    # Oban primarily; the others are cheap and also phase-1 required).
    infra_children = [
      KilnWeb.Telemetry,
      Kiln.Repo,
      {Phoenix.PubSub, name: Kiln.PubSub},
      {Finch, name: Kiln.Finch},
      {Registry, keys: :unique, name: Kiln.RunRegistry},
      {Oban, Application.fetch_env!(:kiln, Oban)}
    ]

    opts = [strategy: :one_for_one, name: Kiln.Supervisor]

    case Supervisor.start_link(infra_children, opts) do
      {:ok, sup_pid} ->
        # Stage 2: assert boot-time invariants (D-32). On failure, raise
        # Kiln.BootChecks.Error propagates up as {:error, ...} from
        # Application.start/2 and the BEAM exits with the message
        # printed to stderr.
        Kiln.BootChecks.run!()

        # Stage 3: attach the Oban telemetry handler (Plan 05). Telemetry
        # handlers are ETS-backed, not process-backed — they aren't
        # supervisor children, so this doesn't affect the D-42 count.
        # Idempotent: returns `{:error, :already_exists}` on re-attach
        # (tolerated so code-reload / iex restarts don't crash).
        _ = ObanHandler.attach()

        # Stage 4: add `KilnWeb.Endpoint` as the 7th child. After this
        # call `Supervisor.which_children(Kiln.Supervisor)` returns
        # EXACTLY 7 entries (asserted by test/kiln/application_test.exs).
        {:ok, _endpoint_pid} = Supervisor.start_child(sup_pid, KilnWeb.Endpoint.child_spec([]))

        {:ok, sup_pid}

      other ->
        other
    end
  end

  @impl true
  def config_change(changed, _new, removed) do
    KilnWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  @impl true
  def stop(_state) do
    _ = ObanHandler.detach()
    :ok
  end
end
