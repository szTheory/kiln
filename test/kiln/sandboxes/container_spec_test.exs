defmodule Kiln.Sandboxes.ContainerSpecTest do
  use ExUnit.Case, async: true

  alias Kiln.Sandboxes.ContainerSpec

  test "defines all D-116 fields" do
    spec = ContainerSpec.defaults()

    assert %ContainerSpec{
             image_ref: _,
             image_digest: _,
             cmd: _,
             env_file_path: _,
             network: _,
             limits: _,
             tmpfs_mounts: _,
             labels: _,
             stop_timeout: _,
             user: _,
             workdir: _,
             security_opts: _,
             cap_drop_all: _,
             read_only: _,
             init: _,
             dns: _,
             extra_hosts: _,
             ipv6_disabled: _
           } = spec
  end

  test "defaults match the hardened sandbox baseline" do
    spec = ContainerSpec.defaults()

    assert spec.cap_drop_all == true
    assert spec.read_only == true
    assert spec.init == true
    assert spec.ipv6_disabled == true
    assert spec.user == "1000:1000"
    assert spec.workdir == "/workspace"
    assert spec.network == "kiln-sandbox"
    assert spec.stop_timeout == 10
  end
end
