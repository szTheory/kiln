defmodule Kiln.Sandboxes.DockerDriver do
  @moduledoc """
  Live Docker sandbox driver (D-115, D-117).

  `run_stage/1` launches a detached `docker run -d --rm ...` container
  via `MuonTrap.cmd/3`, waits for completion, records the outcome in
  `external_operations`, and emits span telemetry with the exact argv
  used to launch the container.

  The driver intentionally never mounts `/var/run/docker.sock`, never
  enables `--privileged`, and never accepts arbitrary bind mounts.
  """

  @behaviour Kiln.Sandboxes.Driver

  require Logger

  alias DockerEngineAPI.Api.Container, as: DockerContainerApi
  alias DockerEngineAPI.Connection, as: DockerConnection
  alias Kiln.ExternalOperations
  alias Kiln.Sandboxes.ContainerSpec

  @docker_api_version "v1.43"
  @docker_socket_path "/var/run/docker.sock"

  @impl true
  def run_stage(%ContainerSpec{} = spec) do
    run_id = label_value(spec.labels, "kiln.run_id")
    stage_run_id = label_value(spec.labels, "kiln.stage_run_id")
    idempotency_key = "run:#{run_id}:stage:#{stage_run_id}:docker_run"
    argv = assemble_argv(spec)

    with {_, op} <-
           external_operations().fetch_or_record_intent(idempotency_key, %{
             op_kind: "docker_run",
             intent_payload: %{
               "image_ref" => spec.image_ref,
               "image_digest" => spec.image_digest,
               "labels" => normalize_map(spec.labels)
             },
             run_id: run_id,
             stage_id: stage_run_id
           }) do
      meta = %{
        run_id: run_id,
        stage_id: stage_run_id,
        docker_argv: argv,
        image_ref: spec.image_ref,
        image_digest: spec.image_digest
      }

      :telemetry.span([:kiln, :sandbox, :docker, :run], meta, fn ->
        case do_run(argv) do
          {:ok, container_id} ->
            result = wait_for_container(container_id)

            case external_operations().complete_op(op, result_payload(result)) do
              {:ok, _updated} ->
                {{:ok, result}, Map.merge(meta, result)}

              {:error, reason} ->
                {{:error, {:complete_op_failed, reason}}, meta}
            end

          {:error, reason} = error ->
            _ = external_operations().fail_op(op, %{"reason" => inspect(reason)})
            {error, Map.put(meta, :error, inspect(reason))}
        end
      end)
    end
  end

  @impl true
  def kill(container_id) when is_binary(container_id) do
    case system_cmd().("docker", ["rm", "-f", container_id], stderr_to_stdout: true) do
      {_output, 0} -> :ok
      {output, code} -> {:error, {:docker_rm_failed, code, output}}
    end
  end

  @impl true
  def list_orphans(boot_epoch) when is_integer(boot_epoch) do
    filters = Jason.encode!(%{"label" => ["kiln.run_id"]})

    case docker_list_fun().(docker_connection(), all: true, filters: filters) do
      {:ok, containers} when is_list(containers) ->
        containers
        |> Enum.flat_map(fn container ->
          labels = Map.get(container, :Labels) || %{}

          case Map.get(labels, "kiln.boot_epoch") do
            nil ->
              []

            epoch ->
              case Integer.parse(to_string(epoch)) do
                {value, ""} when value != boot_epoch -> [Map.get(container, :Id)]
                _ -> []
              end
          end
        end)
        |> Enum.reject(&is_nil/1)

      _ ->
        []
    end
  end

  @doc false
  def __assemble_argv__(%ContainerSpec{} = spec), do: assemble_argv(spec)

  defp assemble_argv(%ContainerSpec{} = spec) do
    stage_run_id = label_value(spec.labels, "kiln.stage_run_id", "unknown")

    [
      "run",
      "-d",
      "--rm",
      "--name",
      "kiln-stage-#{stage_run_id}",
      "--network",
      spec.network
    ] ++
      cap_drop_flag(spec) ++
      security_opts(spec) ++
      read_only_flag(spec) ++
      tmpfs_flags(spec) ++
      [
        "--user",
        spec.user,
        "--memory=#{spec.limits["memory"]}",
        "--memory-swap=#{spec.limits["memory_swap"]}",
        "--cpus=#{spec.limits["cpus"]}",
        "--pids-limit=#{spec.limits["pids_limit"]}",
        "--ulimit",
        "nofile=#{spec.limits["ulimit_nofile"]}",
        "--stop-timeout",
        to_string(spec.stop_timeout)
      ] ++
      label_flags(spec.labels) ++
      env_file_flag(spec.env_file_path) ++
      [
        "--workdir",
        spec.workdir
      ] ++
      init_flag(spec) ++
      dns_flags(spec.dns) ++
      extra_host_flags(spec.extra_hosts) ++
      ipv6_flag(spec) ++
      [
        spec.image_digest || spec.image_ref
      ] ++ spec.cmd
  end

  defp do_run(argv) do
    case muontrap().cmd("docker", argv, stderr_to_stdout: true) do
      {output, 0} ->
        {:ok, String.trim(output)}

      {output, code} ->
        {:error, {:docker_run_failed, code, output}}
    end
  rescue
    error -> {:error, {:docker_run_exception, error}}
  end

  defp wait_for_container(container_id) do
    started_state = inspect_container(container_id)

    exit_code =
      case system_cmd().("docker", ["wait", container_id], stderr_to_stdout: true) do
        {output, 0} ->
          output
          |> String.trim()
          |> Integer.parse()
          |> case do
            {value, ""} -> value
            _ -> Map.get(started_state, :exit_code, 0)
          end

        {_output, code} ->
          code
      end

    finished_state = inspect_container(container_id)

    %{
      container_id: container_id,
      exit_code: exit_code,
      oom_killed:
        Map.get(finished_state, :oom_killed, Map.get(started_state, :oom_killed, false)),
      started_at: Map.get(started_state, :started_at),
      finished_at: Map.get(finished_state, :finished_at, Map.get(started_state, :finished_at))
    }
  end

  defp inspect_container(container_id) do
    format = "{{.State.OOMKilled}}|{{.State.ExitCode}}|{{.State.StartedAt}}|{{.State.FinishedAt}}"

    case system_cmd().("docker", ["inspect", "--format", format, container_id],
           stderr_to_stdout: true
         ) do
      {output, 0} ->
        case String.split(String.trim(output), "|", parts: 4) do
          [oom_killed, exit_code, started_at, finished_at] ->
            %{
              oom_killed: oom_killed == "true",
              exit_code: parse_int(exit_code),
              started_at: started_at,
              finished_at: finished_at
            }

          _ ->
            %{}
        end

      _ ->
        %{}
    end
  end

  defp result_payload(result) do
    %{
      "container_id" => result.container_id,
      "exit_code" => result.exit_code,
      "oom_killed" => result.oom_killed,
      "started_at" => result.started_at,
      "finished_at" => result.finished_at
    }
  end

  defp docker_connection do
    DockerConnection.new(base_url: docker_base_url())
  end

  defp docker_base_url do
    case System.get_env("DOCKER_HOST") do
      nil ->
        "http+unix://#{URI.encode(@docker_socket_path, &URI.char_unreserved?/1)}/#{@docker_api_version}"

      "unix://" <> path ->
        "http+unix://#{URI.encode(path, &URI.char_unreserved?/1)}/#{@docker_api_version}"

      "tcp://" <> host ->
        "http://#{host}/#{@docker_api_version}"

      "http://" <> _ = host ->
        "#{host}/#{@docker_api_version}"

      other ->
        other
    end
  end

  defp cap_drop_flag(%ContainerSpec{cap_drop_all: true}), do: ["--cap-drop=ALL"]
  defp cap_drop_flag(_spec), do: []

  defp security_opts(%ContainerSpec{security_opts: security_opts}) do
    Enum.map(security_opts, &"--security-opt=#{&1}")
  end

  defp read_only_flag(%ContainerSpec{read_only: true}), do: ["--read-only"]
  defp read_only_flag(_spec), do: []

  defp tmpfs_flags(%ContainerSpec{tmpfs_mounts: mounts}) do
    Enum.flat_map(mounts, fn {path, size} ->
      ["--tmpfs", "#{path}:rw,nosuid,size=#{size}"]
    end)
  end

  defp label_flags(labels) do
    Enum.flat_map(labels, fn {key, value} -> ["--label", "#{key}=#{value}"] end)
  end

  defp env_file_flag(nil), do: []
  defp env_file_flag(path), do: ["--env-file", path]

  defp init_flag(%ContainerSpec{init: true}), do: ["--init"]
  defp init_flag(_spec), do: []

  defp dns_flags(dns), do: Enum.flat_map(dns, fn ip -> ["--dns", ip] end)
  defp extra_host_flags(hosts), do: Enum.flat_map(hosts, fn host -> ["--add-host", host] end)

  defp ipv6_flag(%ContainerSpec{ipv6_disabled: true}) do
    ["--sysctl", "net.ipv6.conf.all.disable_ipv6=1"]
  end

  defp ipv6_flag(_spec), do: []

  defp external_operations do
    Keyword.get(runtime_opts(), :external_operations_mod, ExternalOperations)
  end

  defp muontrap do
    Keyword.get(runtime_opts(), :muontrap_mod, MuonTrap)
  end

  defp system_cmd do
    Keyword.get(runtime_opts(), :system_cmd_fun, &System.cmd/3)
  end

  defp docker_list_fun do
    Keyword.get(runtime_opts(), :docker_list_fun, &DockerContainerApi.container_list/2)
  end

  defp runtime_opts do
    Application.get_env(:kiln, __MODULE__, [])
  end

  defp label_value(labels, key, default \\ nil) do
    case Map.get(labels, key, default) do
      nil -> nil
      value -> to_string(value)
    end
  end

  defp normalize_map(map) do
    Map.new(map, fn {key, value} -> {to_string(key), value} end)
  end

  defp parse_int(value) do
    case Integer.parse(to_string(value)) do
      {int, ""} -> int
      _ -> 0
    end
  end
end
