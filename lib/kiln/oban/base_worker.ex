defmodule Kiln.Oban.BaseWorker do
  @moduledoc """
  Base macro for every Kiln Oban worker. Applies safe defaults (D-44)
  and ships three idempotency helpers that delegate to
  `Kiln.ExternalOperations`.

  Usage:

      defmodule MyApp.DoThingWorker do
        use Kiln.Oban.BaseWorker, queue: :default

        @impl Oban.Worker
        def perform(%Oban.Job{args: %{"idempotency_key" => key} = args}) do
          case fetch_or_record_intent(key, %{
                 op_kind: "do_thing",
                 intent_payload: args
               }) do
            {:found_existing, %{state: :completed} = op} ->
              {:ok, op}

            {_status, op} ->
              # ... do the external side-effect idempotently ...
              complete_op(op, %{"result" => "ok"})
          end
        end
      end

  Defaults applied to every `use Kiln.Oban.BaseWorker`:

    * `max_attempts: 3` — overrides Oban's default of 20 (PITFALLS P9;
      retry storms are the prevailing dark-factory failure mode).
    * `unique: [keys: [:idempotency_key], period: :infinity,
      states: [:available, :scheduled, :executing]]` — insert-time
      dedupe on `args -> 'idempotency_key'` so an enqueue racing with
      an in-flight job of the same key collapses into a single
      `oban_jobs` row (D-44).

  Workers MAY override any default by passing the same key in opts:
  `use Kiln.Oban.BaseWorker, max_attempts: 5` ships a max_attempts of 5.

  The helpers `fetch_or_record_intent/2`, `complete_op/2`, `fail_op/2`
  delegate directly to `Kiln.ExternalOperations` — every external
  side-effect plumbs through the two-phase intent → action → completion
  machine defined there (D-18). Nothing is imported; the calling
  worker's module namespace is kept clean so the BaseWorker is
  unintrusive.
  """

  @doc false
  defmacro __using__(opts) do
    opts =
      opts
      |> Keyword.put_new(:max_attempts, 3)
      |> Keyword.put_new(:unique,
        keys: [:idempotency_key],
        period: :infinity,
        states: [:available, :scheduled, :executing]
      )

    quote do
      use Oban.Worker, unquote(opts)

      @doc """
      Delegates to `Kiln.ExternalOperations.fetch_or_record_intent/2`.
      See that module's docs for the two-phase contract.
      """
      @spec fetch_or_record_intent(String.t(), map()) ::
              {:inserted_new, Kiln.ExternalOperations.Operation.t()}
              | {:found_existing, Kiln.ExternalOperations.Operation.t()}
              | {:error, term()}
      def fetch_or_record_intent(key, attrs),
        do: Kiln.ExternalOperations.fetch_or_record_intent(key, attrs)

      @doc "Delegates to `Kiln.ExternalOperations.complete_op/2`."
      @spec complete_op(Kiln.ExternalOperations.Operation.t(), map()) ::
              {:ok, Kiln.ExternalOperations.Operation.t()} | {:error, term()}
      def complete_op(op, result), do: Kiln.ExternalOperations.complete_op(op, result)

      @doc "Delegates to `Kiln.ExternalOperations.fail_op/2`."
      @spec fail_op(Kiln.ExternalOperations.Operation.t(), map()) ::
              {:ok, Kiln.ExternalOperations.Operation.t()} | {:error, term()}
      def fail_op(op, err), do: Kiln.ExternalOperations.fail_op(op, err)
    end
  end
end
