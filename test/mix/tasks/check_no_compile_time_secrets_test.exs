defmodule Mix.Tasks.CheckNoCompileTimeSecretsTest do
  use ExUnit.Case, async: false

  @task Mix.Tasks.CheckNoCompileTimeSecrets

  setup do
    tmp = Path.join(System.tmp_dir!(), "kiln_cts_#{System.unique_integer([:positive])}")
    File.mkdir_p!(Path.join(tmp, "config"))
    original_cwd = File.cwd!()

    on_exit(fn ->
      File.cd!(original_cwd)
      File.rm_rf!(tmp)
    end)

    File.cd!(tmp)
    {:ok, tmp: tmp}
  end

  test "passes when config/*.exs has no System.get_env" do
    File.write!("config/config.exs", ~s|import Config\nconfig :kiln, foo: :bar\n|)
    assert :ok = @task.run([])
  end

  test "fails when config/config.exs contains System.get_env" do
    File.write!(
      "config/config.exs",
      ~s|import Config\nconfig :kiln, key: System.get_env("X")\n|
    )

    assert_raise Mix.Error, ~r/Compile-time secret read detected/, fn ->
      @task.run([])
    end
  end

  test "fails when config/dev.exs contains System.fetch_env!" do
    File.write!(
      "config/dev.exs",
      ~s|import Config\nconfig :kiln, key: System.fetch_env!("X")\n|
    )

    assert_raise Mix.Error, ~r/Compile-time secret read detected/, fn ->
      @task.run([])
    end
  end

  test "ignores config/runtime.exs" do
    File.write!(
      "config/runtime.exs",
      ~s|import Config\nconfig :kiln, key: System.fetch_env!("X")\n|
    )

    assert :ok = @task.run([])
  end
end
