defmodule Kiln.SecretsTest do
  @moduledoc """
  Unit tests for the `Kiln.Secrets` reference-only secret store and the
  `Kiln.Secrets.Ref` struct. Guards D-131 / D-132 / D-133 Layers 1 + 2:

    * Raw strings never appear on a struct field (only the `name` atom).
    * `reveal!/1` is the sole raw-string reveal path.
    * `inspect/1` on a `%Ref{}` renders `#Secret<name>` and MUST NOT
      leak either the raw value or a `%Kiln.Secrets.Ref{...}` default
      struct printer that carries the value.

  Runs `async: false` because `:persistent_term` is a VM-wide global.
  """

  use ExUnit.Case, async: false

  alias Kiln.Secrets
  alias Kiln.Secrets.Ref

  @fake_key "sk-ant-FAKE0000000000000000000000000000000000"

  setup do
    # Ensure a clean slot before each test + clear after.
    Secrets.put(:test_secret_anthropic, nil)
    on_exit(fn -> Secrets.put(:test_secret_anthropic, nil) end)
    :ok
  end

  describe "put/2 + present?/1" do
    test "put with binary value makes present?/1 return true" do
      assert Secrets.present?(:test_secret_anthropic) == false
      assert Secrets.put(:test_secret_anthropic, @fake_key) == :ok
      assert Secrets.present?(:test_secret_anthropic) == true
    end

    test "put with nil clears the secret (test-cleanup path)" do
      Secrets.put(:test_secret_anthropic, @fake_key)
      assert Secrets.present?(:test_secret_anthropic) == true
      assert Secrets.put(:test_secret_anthropic, nil) == :ok
      assert Secrets.present?(:test_secret_anthropic) == false
    end

    test "put with nil on a never-written key is idempotent" do
      assert Secrets.put(:never_written_key, nil) == :ok
      assert Secrets.present?(:never_written_key) == false
    end
  end

  describe "get!/1" do
    test "returns %Ref{} on presence (never the raw value)" do
      Secrets.put(:test_secret_anthropic, @fake_key)
      assert %Ref{name: :test_secret_anthropic} = Secrets.get!(:test_secret_anthropic)
    end

    test "raises on absence — fail loudly, not silently return nil" do
      assert_raise ArgumentError, fn -> Secrets.get!(:not_there_at_all) end
    end
  end

  describe "get/1" do
    test "returns {:ok, %Ref{}} on presence" do
      Secrets.put(:test_secret_anthropic, @fake_key)
      assert {:ok, %Ref{name: :test_secret_anthropic}} = Secrets.get(:test_secret_anthropic)
    end

    test "returns :error on absence (non-raising variant)" do
      assert Secrets.get(:not_there_at_all) == :error
    end
  end

  describe "reveal!/1" do
    test "accepts %Ref{} and returns raw binary" do
      Secrets.put(:test_secret_anthropic, @fake_key)
      ref = Secrets.get!(:test_secret_anthropic)
      assert Secrets.reveal!(ref) == @fake_key
    end

    test "accepts bare atom name and returns raw binary" do
      Secrets.put(:test_secret_anthropic, @fake_key)
      assert Secrets.reveal!(:test_secret_anthropic) == @fake_key
    end

    test "raises on missing name (bare atom)" do
      assert_raise ArgumentError, fn -> Secrets.reveal!(:not_there_at_all) end
    end

    test "raises on missing name wrapped in a %Ref{}" do
      assert_raise ArgumentError, fn ->
        Secrets.reveal!(%Ref{name: :not_there_at_all})
      end
    end
  end

  describe "%Ref{} inspect protocol (D-133 Layer 2)" do
    test "inspect renders #Secret<name> — never the raw value" do
      Secrets.put(:test_secret_anthropic, @fake_key)
      ref = Secrets.get!(:test_secret_anthropic)
      rendered = inspect(ref)

      assert rendered == "#Secret<test_secret_anthropic>"
      refute rendered =~ @fake_key
      refute rendered =~ ~r/sk-ant-/
    end

    test "inspect of a surrounding container does not leak via default printer" do
      Secrets.put(:test_secret_anthropic, @fake_key)
      ref = Secrets.get!(:test_secret_anthropic)
      rendered = inspect(%{ref: ref, extra: :data})

      assert rendered =~ "#Secret<test_secret_anthropic>"
      refute rendered =~ @fake_key
      refute rendered =~ ~r/sk-ant-/
    end

    test "%Ref{} struct has exactly one field (:name) — no raw-value slot" do
      ref = %Ref{name: :anthropic_api_key}
      fields = Map.from_struct(ref) |> Map.keys()
      assert fields == [:name]
    end
  end
end
