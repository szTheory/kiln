defmodule Kiln.GitHub.DogfoodTest do
  use Kiln.ObanCase, async: false

  import Ecto.Query

  alias Kiln.ExternalOperations.Operation
  alias Kiln.GitHub.Dogfood
  alias Kiln.Repo
  alias Kiln.Workers.DogfoodPRWorker

  setup do
    on_exit(fn -> Application.delete_env(:kiln, Dogfood) end)
    :ok
  end

  test "path allowlist rejects workflow edits" do
    assert {:error, {:path_allowlist, [".github/workflows/ci.yml"]}} =
             Dogfood.validate_changed_paths!(["lib/kiln/version.ex", ".github/workflows/ci.yml"])
  end

  test "DogfoodPRWorker completes when sync_fun succeeds" do
    :ok =
      Application.put_env(:kiln, Dogfood, sync_fun: fn _ -> {:ok, %{"status" => "stub"}} end)

    key = "dogfood:testhash:pr_sync"

    args = %{
      "idempotency_key" => key,
      "paths" => ["lib/kiln/version.ex"],
      "spec_hash" => "testhash"
    }

    assert {:ok, :completed} = perform_job(DogfoodPRWorker, args)
    assert {:ok, :duplicate_suppressed} = perform_job(DogfoodPRWorker, args)

    assert Repo.aggregate(from(o in Operation, where: o.idempotency_key == ^key), :count) == 1
  end
end
