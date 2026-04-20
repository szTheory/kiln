defmodule Kiln.Sandboxes do
  @moduledoc """
  Execution layer for Phase 3's ephemeral Docker sandboxes.

  Every stage runs inside a hardened container launched through
  `Kiln.Sandboxes.Driver` and the live `Kiln.Sandboxes.DockerDriver`
  implementation. The runtime shape is intentionally narrow:

    * network pinned to `kiln-sandbox`
    * `--cap-drop=ALL`
    * `--security-opt=no-new-privileges`
    * read-only rootfs plus tmpfs work surfaces
    * no Docker socket mount, no `--privileged`

  Host-side support lives under `Kiln.Sandboxes.Supervisor`, which starts
  `Kiln.Sandboxes.OrphanSweeper` before any run dispatch so prior-boot
  containers can be removed and recorded as `:orphan_container_swept`
  audit events.
  """
end
