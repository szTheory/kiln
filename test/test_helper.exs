ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(Kiln.Repo, :manual)

# Start Credo so custom-check tests can use `Credo.Test.Case` helpers,
# which rely on `Credo.Service.SourceFileAST` and friends being alive.
{:ok, _} = Application.ensure_all_started(:credo)
