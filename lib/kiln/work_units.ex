defmodule Kiln.WorkUnits do
  @moduledoc """
  Transactional command surface for work-unit coordination (AGENT-04).

  All mutations run inside `Repo.transact/2` with paired
  `work_unit_events` rows. `Phoenix.PubSub` broadcasts fire only after a
  successful commit.
  """

  import Ecto.Query

  alias Kiln.Repo
  alias Kiln.WorkUnits.Dependency
  alias Kiln.WorkUnits.PubSub, as: WUPubSub
  alias Kiln.WorkUnits.ReadyQuery
  alias Kiln.WorkUnits.WorkUnit
  alias Kiln.WorkUnits.WorkUnitEvent

  @type work_unit :: WorkUnit.t()

  @doc """
  When a run has no work units yet, inserts the canonical `:planner` seed.
  """
  @spec seed_initial_planner_unit(Ecto.UUID.t()) ::
          {:ok, work_unit() | :already_seeded} | {:error, term()}
  def seed_initial_planner_unit(run_id) when is_binary(run_id) do
    result =
      Repo.transact(fn ->
        if Repo.exists?(from w in WorkUnit, where: w.run_id == ^run_id) do
          {:ok, :already_seeded}
        else
          attrs = %{run_id: run_id, agent_role: :planner, input_payload: %{}, result_payload: %{}}

          with {:ok, wu} <- insert_unit(attrs),
               {:ok, _} <- append_event(wu.id, :created, %{payload: %{}}) do
            {:ok, wu}
          end
        end
      end)

    case result do
      {:ok, %WorkUnit{} = wu} ->
        WUPubSub.broadcast_change(pub_payload(wu, :created))
        {:ok, wu}

      {:ok, :already_seeded} ->
        {:ok, :already_seeded}

      other ->
        other
    end
  end

  @doc """
  Inserts a work unit and an accompanying `:created` ledger event.
  """
  @spec create_work_unit(map()) :: {:ok, work_unit()} | {:error, term()}
  def create_work_unit(attrs) when is_map(attrs) do
    result =
      Repo.transact(fn ->
        with {:ok, wu} <- insert_unit(attrs),
             {:ok, _} <- append_event(wu.id, :created, %{payload: event_payload(attrs)}) do
          {:ok, wu}
        end
      end)

    case result do
      {:ok, %WorkUnit{} = wu} ->
        WUPubSub.broadcast_change(pub_payload(wu, :created))
        {:ok, wu}

      other ->
        other
    end
  end

  @doc false
  @spec get_work_unit!(Ecto.UUID.t()) :: work_unit()
  def get_work_unit!(id), do: Repo.get!(WorkUnit, id)

  @doc false
  @spec list_run_work_units(Ecto.UUID.t()) :: [work_unit()]
  def list_run_work_units(run_id) when is_binary(run_id) do
    from(w in WorkUnit,
      where: w.run_id == ^run_id,
      order_by: [asc: w.inserted_at]
    )
    |> Repo.all()
  end

  @doc """
  Claims the next ready work unit for `role` within `run_id`.

  Uses `FOR UPDATE SKIP LOCKED` on the ready query for safe concurrency.
  """
  @spec claim_next_ready(Ecto.UUID.t(), atom()) ::
          {:ok, work_unit()} | {:error, :none_ready | :role_mismatch | term()}
  def claim_next_ready(run_id, role) when is_binary(run_id) and is_atom(role) do
    result =
      Repo.transact(fn ->
        query =
          ReadyQuery.ready_for_run(run_id)
          |> limit(1)
          |> lock("FOR UPDATE SKIP LOCKED")

        case Repo.one(query) do
          nil ->
            {:error, :none_ready}

          wu ->
            if wu.agent_role != role do
              {:error, :role_mismatch}
            else
              now = DateTime.utc_now(:microsecond)

              {count, _} =
                from(x in WorkUnit,
                  where: x.id == ^wu.id,
                  where: x.updated_at == ^wu.updated_at,
                  where: x.state in [:open, :blocked],
                  where: x.blockers_open_count == 0
                )
                |> Repo.update_all(
                  set: [
                    state: :in_progress,
                    claimed_by_role: role,
                    claimed_at: now,
                    updated_at: now
                  ]
                )

              case count do
                0 ->
                  {:error, :none_ready}

                1 ->
                  claimed = Repo.get!(WorkUnit, wu.id)

                  case append_event(claimed.id, :claimed, %{actor_role: role}) do
                    {:ok, _} -> {:ok, claimed}
                    {:error, _} = err -> err
                  end
              end
            end
        end
      end)

    case result do
      {:ok, %WorkUnit{} = wu} ->
        WUPubSub.broadcast_change(pub_payload(wu, :claimed))
        {:ok, wu}

      other ->
        other
    end
  end

  @doc """
  Marks `current_id` completed + closed and inserts successor units, all
  atomically. Successor maps must include at least `:agent_role`.
  """
  @spec complete_and_handoff(Ecto.UUID.t(), atom(), [map()]) ::
          {:ok, {work_unit(), [work_unit()]}} | {:error, term()}
  def complete_and_handoff(current_id, role, successors)
      when is_binary(current_id) and is_atom(role) and is_list(successors) do
    result =
      Repo.transact(fn ->
        wu =
          Repo.one(
            from(x in WorkUnit,
              where: x.id == ^current_id,
              lock: "FOR UPDATE"
            )
          )

        now = DateTime.utc_now(:microsecond)

        with %WorkUnit{} <- wu,
             true <- wu.agent_role == role,
             {:ok, completed} <- Repo.update(WorkUnit.changeset(wu, %{state: :completed})),
             {:ok, _} <- append_event(completed.id, :completed, %{actor_role: role}),
             {:ok, closed} <-
               Repo.update(WorkUnit.changeset(completed, %{state: :closed, closed_at: now})),
             {:ok, _} <- append_event(closed.id, :closed, %{actor_role: role}),
             {:ok, succ} <- insert_successors(closed.run_id, successors) do
          {:ok, {closed, succ}}
        else
          nil -> {:error, :not_found}
          false -> {:error, :role_mismatch}
          {:error, _} = err -> err
        end
      end)

    case result do
      {:ok, {closed, succ}} ->
        WUPubSub.broadcast_change(pub_payload(closed, :handoff_complete))

        Enum.each(succ, fn s ->
          WUPubSub.broadcast_change(pub_payload(s, :created))
        end)

        {:ok, {closed, succ}}

      other ->
        other
    end
  end

  @doc """
  Adds a blocker edge and bumps `blockers_open_count` on the blocked unit.
  """
  @spec block_work_unit(Ecto.UUID.t(), Ecto.UUID.t()) :: {:ok, work_unit()} | {:error, term()}
  def block_work_unit(blocked_work_unit_id, blocker_work_unit_id)
      when is_binary(blocked_work_unit_id) and is_binary(blocker_work_unit_id) do
    result =
      Repo.transact(fn ->
        blocked =
          Repo.one(
            from w in WorkUnit,
              where: w.id == ^blocked_work_unit_id,
              lock: "FOR UPDATE"
          )

        blocker = blocked && Repo.get(WorkUnit, blocker_work_unit_id)

        case {blocked, blocker} do
          {nil, _} ->
            {:error, :not_found}

          {_, nil} ->
            {:error, :not_found}

          {%WorkUnit{} = blocked, %WorkUnit{} = blocker} ->
            with :ok <- assert_same_run(blocked, blocker),
                 {:ok, _} <- insert_dependency_row(blocked_work_unit_id, blocker_work_unit_id),
                 {:ok, bumped} <- bump_blockers(blocked, 1),
                 {:ok, _} <-
                   append_event(bumped.id, :blocked, %{
                     payload: %{blocker_work_unit_id: blocker_work_unit_id}
                   }) do
              {:ok, bumped}
            end
        end
      end)

    case result do
      {:ok, %WorkUnit{} = wu} ->
        WUPubSub.broadcast_change(pub_payload(wu, :blocked))
        {:ok, wu}

      other ->
        other
    end
  end

  @doc """
  Removes a blocker edge and decrements `blockers_open_count`. Appends
  `:unblocked` when the count reaches zero.
  """
  @spec unblock_work_unit(Ecto.UUID.t(), Ecto.UUID.t()) :: {:ok, work_unit()} | {:error, term()}
  def unblock_work_unit(blocked_work_unit_id, blocker_work_unit_id)
      when is_binary(blocked_work_unit_id) and is_binary(blocker_work_unit_id) do
    result =
      Repo.transact(fn ->
        blocked =
          Repo.one(
            from w in WorkUnit,
              where: w.id == ^blocked_work_unit_id,
              lock: "FOR UPDATE"
          )

        case blocked do
          nil ->
            {:error, :not_found}

          %WorkUnit{} = blocked ->
            deleted =
              Repo.delete_all(
                from d in Dependency,
                  where:
                    d.blocked_work_unit_id == ^blocked_work_unit_id and
                      d.blocker_work_unit_id == ^blocker_work_unit_id
              )

            case deleted do
              {0, _} ->
                {:error, :no_such_dependency}

              {_n, _} ->
                with {:ok, lowered} <- bump_blockers(blocked, -1),
                     {:ok, _} <- maybe_unblocked_event(lowered, blocker_work_unit_id) do
                  {:ok, lowered}
                end
            end
        end
      end)

    case result do
      {:ok, %WorkUnit{} = wu} ->
        WUPubSub.broadcast_change(pub_payload(wu, :unblocked))
        {:ok, wu}

      other ->
        other
    end
  end

  @doc """
  Closes a work unit (terminal). Caller role must match `agent_role`.
  """
  @spec close_work_unit(Ecto.UUID.t(), atom()) :: {:ok, work_unit()} | {:error, term()}
  def close_work_unit(id, role) when is_binary(id) and is_atom(role) do
    result =
      Repo.transact(fn ->
        wu = Repo.one(from x in WorkUnit, where: x.id == ^id, lock: "FOR UPDATE")

        with %WorkUnit{} <- wu,
             true <- wu.agent_role == role,
             now = DateTime.utc_now(:microsecond),
             {:ok, closed} <-
               Repo.update(WorkUnit.changeset(wu, %{state: :closed, closed_at: now})),
             {:ok, _} <- append_event(closed.id, :closed, %{actor_role: role}) do
          {:ok, closed}
        else
          nil -> {:error, :not_found}
          false -> {:error, :role_mismatch}
          {:error, _} = err -> err
        end
      end)

    case result do
      {:ok, %WorkUnit{} = wu} ->
        WUPubSub.broadcast_change(pub_payload(wu, :closed))
        {:ok, wu}

      other ->
        other
    end
  end

  # -- internals ----------------------------------------------------------

  defp insert_unit(attrs) do
    %WorkUnit{}
    |> WorkUnit.changeset(attrs)
    |> Repo.insert()
  end

  defp append_event(work_unit_id, kind, extra) when is_binary(work_unit_id) and is_atom(kind) do
    base = %{
      work_unit_id: work_unit_id,
      event_kind: kind,
      occurred_at: DateTime.utc_now(:microsecond),
      payload: Map.get(extra, :payload, %{})
    }

    base =
      case Map.get(extra, :actor_role) do
        nil -> base
        role -> Map.put(base, :actor_role, role)
      end

    %WorkUnitEvent{}
    |> WorkUnitEvent.changeset(base)
    |> Repo.insert()
  end

  defp event_payload(attrs) do
    attrs
    |> Map.take([:external_ref])
    |> Enum.reject(fn {_, v} -> is_nil(v) end)
    |> Map.new()
  end

  defp pub_payload(%WorkUnit{id: id, run_id: run_id}, event) do
    %{id: id, run_id: run_id, event: event}
  end

  defp insert_successors(run_id, successors) do
    Enum.reduce_while(successors, {:ok, []}, fn attrs, {:ok, acc} ->
      attrs =
        attrs
        |> Map.put_new(:input_payload, %{})
        |> Map.put_new(:result_payload, %{})
        |> Map.put(:run_id, run_id)

      with {:ok, wu} <- insert_unit(attrs),
           {:ok, _} <- append_event(wu.id, :created, %{payload: event_payload(attrs)}) do
        {:cont, {:ok, [wu | acc]}}
      else
        {:error, _} = err -> {:halt, err}
      end
    end)
    |> case do
      {:ok, list} -> {:ok, Enum.reverse(list)}
      {:error, _} = err -> err
    end
  end

  defp assert_same_run(%WorkUnit{run_id: r}, %WorkUnit{run_id: r}), do: :ok
  defp assert_same_run(_, _), do: {:error, :cross_run_dependency}

  defp insert_dependency_row(blocked_id, blocker_id) do
    %Dependency{}
    |> Dependency.changeset(%{
      blocked_work_unit_id: blocked_id,
      blocker_work_unit_id: blocker_id
    })
    |> Repo.insert()
  end

  defp bump_blockers(%WorkUnit{} = wu, delta) do
    new_count = wu.blockers_open_count + delta

    if new_count < 0 do
      {:error, :blockers_underflow}
    else
      wu
      |> WorkUnit.changeset(%{blockers_open_count: new_count})
      |> Repo.update()
    end
  end

  defp maybe_unblocked_event(%WorkUnit{blockers_open_count: 0} = wu, blocker_id) do
    append_event(wu.id, :unblocked, %{payload: %{blocker_work_unit_id: blocker_id}})
  end

  defp maybe_unblocked_event(_wu, _blocker_id), do: {:ok, :skip}
end
