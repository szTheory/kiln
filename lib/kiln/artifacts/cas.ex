defmodule Kiln.Artifacts.CAS do
  @moduledoc """
  Content-addressed-storage primitives for `Kiln.Artifacts` (D-77).

  Blobs are written via a streaming SHA-256 hash into a UUID-named
  temp file under `tmp_root`, then atomically `rename(2)`'d into place at
  `<cas_root>/<aa>/<bb>/<sha>` (two-level fan-out = 65,536 dirs; handles
  millions of blobs without ext4/APFS directory-size pathology). After
  the rename the blob is `chmod 0444` (read-only).

  **Atomic-rename pitfall (Pitfall #3 in 02-RESEARCH.md Pattern 5):**
  `rename(2)` is atomic ONLY when source + destination live on the same
  filesystem. `cas_root` and `tmp_root` MUST therefore live under the
  same mount point. The defaults (`priv/artifacts/cas` +
  `priv/artifacts/tmp`) satisfy this; operators who override via
  `config :kiln, :artifacts, cas_root: ..., tmp_root: ...` MUST ensure
  both point at the same filesystem (e.g. both on `/var/lib/kiln` or
  both in `System.tmp_dir!()`). Cross-filesystem rename degrades to a
  copy-then-delete which is NOT atomic — a crash mid-copy leaves a
  partial blob visible at its final path.

  See `.planning/phases/02-workflow-engine-core/02-RESEARCH.md` Pattern
  5 for the full rationale.

  Public API:

    * `put_stream/1` — stream an `Enumerable.t()` of iodata through
      SHA-256, atomically move into CAS, chmod read-only. Returns
      `{:ok, sha_hex, size_bytes}` on success.
    * `cas_path/1` — pure function mapping a 64-hex sha to the on-disk
      path (`<cas_root>/<aa>/<bb>/<sha>`). Does NOT touch the filesystem.
  """

  @cas_root Application.compile_env(:kiln, [:artifacts, :cas_root], "priv/artifacts/cas")
  @tmp_root Application.compile_env(:kiln, [:artifacts, :tmp_root], "priv/artifacts/tmp")

  @doc """
  Stream `body` (an `Enumerable.t()` of iodata chunks) through a
  SHA-256 hash while writing the bytes to a UUID-named temp file; on
  stream end, compute the final digest, ensure the two-level fan-out
  directories exist, and atomically rename the temp file to its CAS
  path. The final blob is set read-only (`chmod 0444`).

  Returns `{:ok, sha_hex, size_bytes}` on success, or
  `{:error, {:rename_failed, reason}}` if the atomic rename fails (e.g.
  cross-filesystem boundary — see `@moduledoc`). Any exception raised
  by the underlying file IO propagates as-is (`File.open!/3`,
  `:file.write/2`).

  Note: `cas_root` and `tmp_root` are captured at COMPILE time via
  `Application.compile_env/3`, so runtime `Application.put_env/3`
  changes do NOT affect an already-compiled module. For finer-grained
  per-test overrides, recompile (or use `Kiln.CasTestHelper` which
  overrides the env BEFORE tests exercise this module).
  """
  @spec put_stream(Enumerable.t()) ::
          {:ok, String.t(), non_neg_integer()} | {:error, {:rename_failed, term()}}
  def put_stream(body) do
    File.mkdir_p!(@tmp_root)
    tmp_path = Path.join(@tmp_root, Ecto.UUID.generate())

    File.open!(tmp_path, [:write, :binary, :raw], fn fd ->
      {hash_state, size} =
        Enum.reduce(body, {:crypto.hash_init(:sha256), 0}, fn chunk, {h, sz} ->
          :ok = :file.write(fd, chunk)
          {:crypto.hash_update(h, chunk), sz + IO.iodata_length(chunk)}
        end)

      digest = :crypto.hash_final(hash_state)
      sha_hex = Base.encode16(digest, case: :lower)
      final_path = cas_path(sha_hex)
      File.mkdir_p!(Path.dirname(final_path))

      case File.rename(tmp_path, final_path) do
        :ok ->
          # chmod 0444 — blob is immutable once in CAS. Failure to chmod
          # is non-fatal (e.g. some FUSE filesystems don't support it);
          # the integrity contract is enforced by the sha256 re-hash in
          # Kiln.Artifacts.read!/1, not by filesystem mode bits.
          _ = File.chmod(final_path, 0o444)
          {sha_hex, size}

        {:error, reason} ->
          # Rename failed — best-effort cleanup of the tmp file before
          # throwing so the catch clause can return a typed error.
          _ = File.rm(tmp_path)
          throw({:rename_failed, reason})
      end
    end)
  catch
    {:rename_failed, reason} -> {:error, {:rename_failed, reason}}
  else
    {sha_hex, size} -> {:ok, sha_hex, size}
  end

  @doc """
  Compute the on-disk CAS path for a given 64-char lowercase hex SHA-256.
  Pure function — does NOT touch the filesystem.

  Uses the first 4 hex characters as a two-level fan-out:
  `<cas_root>/<sha[0..1]>/<sha[2..3]>/<sha>`. Any input that isn't at
  least 4 characters of binary data will fail the bit-size guard clause
  (which is the T1 path-traversal mitigation — only sha-hex-shaped
  input produces a valid path).
  """
  @spec cas_path(String.t()) :: String.t()
  def cas_path(<<aa::binary-size(2), bb::binary-size(2), _::binary>> = sha) do
    Path.join([@cas_root, aa, bb, sha])
  end

  @doc """
  Returns the compile-time-captured CAS root path. Primarily for tests
  and debugging; production code addresses blobs via `cas_path/1`.
  """
  @spec cas_root() :: String.t()
  def cas_root, do: @cas_root

  @doc """
  Returns the compile-time-captured tmp root path. Primarily for tests
  and debugging.
  """
  @spec tmp_root() :: String.t()
  def tmp_root, do: @tmp_root
end
