defmodule Kiln.Specs do
  @moduledoc """
  Intent layer — spec parsing and normalization. Phase 2 ships the real
  `Kiln.Specs.parse/2` (YAML frontmatter + Markdown body) and schema.

  This P1 placeholder exists so `Kiln.BootChecks` can assert the full
  12-context naming contract at boot (D-42) rather than staging it in
  across Phases 2-6. Keeping the module pinned from P1 prevents
  downstream-phase drift (a phase can't accidentally rename its
  context without breaking the boot check).
  """
end
