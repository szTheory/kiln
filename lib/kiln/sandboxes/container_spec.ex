defmodule Kiln.Sandboxes.ContainerSpec do
  @moduledoc """
  Immutable container launch data for the sandbox driver (D-116, D-117).

  The Docker driver assembles `docker run` arguments from this struct.
  Defaults encode the hardened baseline so callers only override the
  fields that vary by stage.
  """

  @enforce_keys [:image_ref, :image_digest]
  defstruct [
    :image_ref,
    :image_digest,
    :env_file_path,
    cmd: [],
    network: "kiln-sandbox",
    limits: %{},
    tmpfs_mounts: [],
    labels: %{},
    stop_timeout: 10,
    user: "1000:1000",
    workdir: "/workspace",
    security_opts: ["no-new-privileges", "seccomp=default"],
    cap_drop_all: true,
    read_only: true,
    init: true,
    dns: [],
    extra_hosts: [],
    ipv6_disabled: true
  ]

  @type t :: %__MODULE__{
          image_ref: String.t(),
          image_digest: String.t(),
          env_file_path: String.t() | nil,
          cmd: [String.t()],
          network: String.t(),
          limits: map(),
          tmpfs_mounts: [{String.t(), String.t()}],
          labels: %{optional(String.t()) => String.t() | integer()},
          stop_timeout: pos_integer(),
          user: String.t(),
          workdir: String.t(),
          security_opts: [String.t()],
          cap_drop_all: boolean(),
          read_only: boolean(),
          init: boolean(),
          dns: [String.t()],
          extra_hosts: [String.t()],
          ipv6_disabled: boolean()
        }

  @spec defaults() :: t()
  def defaults do
    %__MODULE__{
      image_ref: "",
      image_digest: ""
    }
  end
end
