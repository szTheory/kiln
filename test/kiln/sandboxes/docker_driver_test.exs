defmodule Kiln.Sandboxes.DockerDriverTest do
  use Kiln.DataCase, async: false

  require Logger

  alias Kiln.ExternalOperations.Operation
  alias Kiln.Sandboxes.{ContainerSpec, DockerDriver}

  defmodule MuonTrapStub do
    def cmd("docker", argv, opts) do
      send(self(), {:muontrap_cmd, argv, opts})
      {"container-123\n", 0}
    end
  end

  setup do
    Logger.metadata(correlation_id: Ecto.UUID.generate())

    handler_id = "docker-driver-test-#{System.unique_integer([:positive])}"
    parent = self()

    :ok =
      :telemetry.attach_many(
        handler_id,
        [
          [:kiln, :sandbox, :docker, :run, :start],
          [:kiln, :sandbox, :docker, :run, :stop]
        ],
        fn event, measurements, metadata, _config ->
          send(parent, {:telemetry_event, event, measurements, metadata})
        end,
        nil
      )

    system_cmd_fun = fn
      "docker", ["wait", "container-123"], _opts ->
        {"17\n", 0}

      "docker", ["inspect", "--format", _format, "container-123"], _opts ->
        {"true|17|2026-04-20T01:00:00Z|2026-04-20T01:01:00Z", 0}

      "docker", ["rm", "-f", id], _opts ->
        {"#{id}\n", 0}
    end

    Application.put_env(:kiln, DockerDriver,
      muontrap_mod: MuonTrapStub,
      system_cmd_fun: system_cmd_fun
    )

    on_exit(fn ->
      :telemetry.detach(handler_id)
      Application.delete_env(:kiln, DockerDriver)
      Logger.metadata(correlation_id: nil)
    end)

    :ok
  end

  describe "Driver behaviour" do
    test "exposes run_stage/1, kill/1, list_orphans/1 callbacks" do
      behaviours =
        Kiln.Sandboxes.Driver.behaviour_info(:callbacks)
        |> Enum.map(fn {name, arity} -> {name, arity} end)

      assert {:run_stage, 1} in behaviours
      assert {:kill, 1} in behaviours
      assert {:list_orphans, 1} in behaviours
    end
  end

  describe "__assemble_argv__/1" do
    test "builds the full D-117 hardened argv" do
      stage_run_id = Ecto.UUID.generate()

      spec = %ContainerSpec{
        image_ref: "kiln/sandbox-elixir:abc",
        image_digest: "kiln/sandbox-elixir@sha256:def",
        env_file_path: "priv/run/#{stage_run_id}.env",
        cmd: ["mix", "test"],
        network: "kiln-sandbox",
        limits: %{
          "memory" => "768m",
          "memory_swap" => "768m",
          "cpus" => 1,
          "pids_limit" => 256,
          "ulimit_nofile" => "4096:8192"
        },
        tmpfs_mounts: [{"/tmp", "128m"}, {"/workspace", "512m"}],
        labels: %{
          "kiln.run_id" => Ecto.UUID.generate(),
          "kiln.stage_run_id" => stage_run_id,
          "kiln.boot_epoch" => 12_345,
          "kiln.stage_kind" => "coding"
        },
        dns: ["172.28.0.10"],
        extra_hosts: ["api.github.com:172.28.0.10"]
      }

      argv = DockerDriver.__assemble_argv__(spec)

      assert Enum.take(argv, 3) == ["run", "-d", "--rm"]
      assert "--network" in argv
      assert "kiln-sandbox" in argv
      assert "--cap-drop=ALL" in argv
      assert "--security-opt=no-new-privileges" in argv
      assert "--security-opt=seccomp=default" in argv
      assert "--read-only" in argv
      assert "--tmpfs" in argv
      assert "/tmp:rw,nosuid,size=128m" in argv
      assert "/workspace:rw,nosuid,size=512m" in argv
      assert "--user" in argv
      assert "1000:1000" in argv
      assert "--memory=768m" in argv
      assert "--memory-swap=768m" in argv
      assert "--cpus=1" in argv
      assert "--pids-limit=256" in argv
      assert "--ulimit" in argv
      assert "nofile=4096:8192" in argv
      assert "--stop-timeout" in argv
      assert "10" in argv
      assert "--workdir" in argv
      assert "/workspace" in argv
      assert "--init" in argv
      assert "--env-file" in argv
      assert "priv/run/#{stage_run_id}.env" in argv
      assert "--dns" in argv
      assert "172.28.0.10" in argv
      assert "--add-host" in argv
      assert "api.github.com:172.28.0.10" in argv
      assert "--sysctl" in argv
      assert "net.ipv6.conf.all.disable_ipv6=1" in argv
      assert "--name" in argv
      assert "kiln-stage-#{stage_run_id}" in argv
      assert Enum.any?(argv, &(&1 == "--label"))
      assert Enum.any?(argv, &(&1 == "kiln.run_id=#{spec.labels["kiln.run_id"]}"))
      assert Enum.any?(argv, &(&1 == "kiln.boot_epoch=12345"))
    end

    test "never adds --privileged or docker.sock mounts" do
      spec = %ContainerSpec{
        image_ref: "image",
        image_digest: "image@sha256:1",
        limits: %{
          "memory" => "1g",
          "memory_swap" => "1g",
          "cpus" => 1,
          "pids_limit" => 100,
          "ulimit_nofile" => "1024:1024"
        }
      }

      argv = DockerDriver.__assemble_argv__(spec)

      refute "--privileged" in argv
      refute Enum.any?(argv, &String.contains?(&1, "docker.sock"))
      refute Enum.any?(argv, &(&1 == "-v"))
    end
  end

  describe "run_stage/1" do
    test "emits telemetry with full argv metadata and records docker_run external op" do
      run_id = Ecto.UUID.generate()
      stage_run_id = Ecto.UUID.generate()

      spec = %ContainerSpec{
        image_ref: "kiln/sandbox-elixir:abc",
        image_digest: "kiln/sandbox-elixir@sha256:def",
        env_file_path: "priv/run/#{stage_run_id}.env",
        cmd: ["mix", "test"],
        limits: %{
          "memory" => "768m",
          "memory_swap" => "768m",
          "cpus" => 1,
          "pids_limit" => 256,
          "ulimit_nofile" => "4096:8192"
        },
        tmpfs_mounts: [{"/tmp", "128m"}, {"/workspace", "512m"}],
        labels: %{
          "kiln.run_id" => run_id,
          "kiln.stage_run_id" => stage_run_id,
          "kiln.boot_epoch" => 12_345
        },
        dns: ["172.28.0.10"],
        extra_hosts: ["api.github.com:172.28.0.10"]
      }

      assert {:ok,
              %{
                container_id: "container-123",
                exit_code: 17,
                oom_killed: true,
                started_at: "2026-04-20T01:00:00Z",
                finished_at: "2026-04-20T01:01:00Z"
              }} = DockerDriver.run_stage(spec)

      assert_received {:telemetry_event, [:kiln, :sandbox, :docker, :run, :start], _measurements,
                       start_meta}

      assert is_list(start_meta.docker_argv)
      assert "kiln-stage-#{stage_run_id}" in start_meta.docker_argv

      assert_received {:telemetry_event, [:kiln, :sandbox, :docker, :run, :stop], _measurements,
                       stop_meta}

      assert stop_meta.container_id == "container-123"
      assert stop_meta.exit_code == 17
      assert stop_meta.oom_killed
      assert is_list(stop_meta.docker_argv)

      assert_received {:muontrap_cmd, argv, opts}
      assert Enum.take(argv, 3) == ["run", "-d", "--rm"]
      assert opts[:stderr_to_stdout]

      op =
        Repo.one!(
          from(o in Operation,
            where: o.run_id == ^run_id and o.stage_id == ^stage_run_id
          )
        )

      assert op.op_kind == "docker_run"
      assert op.state == :completed
      assert op.result_payload["container_id"] == "container-123"
      assert op.result_payload["exit_code"] == 17
      assert op.result_payload["oom_killed"]
      assert op.result_payload["started_at"] == "2026-04-20T01:00:00Z"
      assert op.result_payload["finished_at"] == "2026-04-20T01:01:00Z"
    end
  end
end
