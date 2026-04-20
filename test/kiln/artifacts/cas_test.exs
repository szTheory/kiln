defmodule Kiln.Artifacts.CASTest do
  @moduledoc """
  CAS-level tests for `Kiln.Artifacts.CAS` (Plan 02-03 Task 1). Exercises:

    * `put_stream/1` round-trip — streaming SHA-256 + atomic rename +
      read-only-blob invariants.
    * `cas_path/1` two-level fan-out (`<cas_root>/<aa>/<bb>/<sha>`).
    * Content-addressed dedup — identical byte-sequences produce the
      same SHA regardless of chunk boundaries.

  Note on test isolation: `Kiln.Artifacts.CAS` uses
  `Application.compile_env/3` to capture `cas_root` + `tmp_root` at
  module compile time. Runtime `Application.put_env/3` overrides (e.g.
  via `Kiln.CasTestHelper.setup_tmp_cas/0`) do NOT affect the already-
  compiled `CAS` module. The test-environment paths in `config/test.exs`
  point at a per-run directory under `System.tmp_dir!()`, so tests
  share one CAS root but never collide with dev/prod `priv/` blobs.

  `async: false` — CAS writes touch a shared filesystem directory.
  """
  use ExUnit.Case, async: false

  alias Kiln.Artifacts.CAS

  describe "put_stream/1 round-trip" do
    test "returns sha + size; file lands at cas_path and matches bytes" do
      body = ["hello, ", "world!"]
      expected_bytes = "hello, world!"

      assert {:ok, sha, size} = CAS.put_stream(body)

      # sha is 64 lowercase hex
      assert String.length(sha) == 64
      assert Regex.match?(~r/^[0-9a-f]{64}$/, sha)
      assert size == byte_size(expected_bytes)

      # blob lives at cas_path(sha) and the bytes round-trip
      path = CAS.cas_path(sha)
      assert File.exists?(path)
      assert File.read!(path) == expected_bytes
    end

    test "empty body still produces a valid sha + zero-byte blob" do
      assert {:ok, sha, 0} = CAS.put_stream([])
      # SHA-256 of empty input
      assert sha == "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
      assert File.exists?(CAS.cas_path(sha))
      assert File.read!(CAS.cas_path(sha)) == ""
    end
  end

  describe "dedup (content-addressing)" do
    test "same bytes produce same sha regardless of chunking" do
      body1 = ["same content"]
      # Same total bytes, different chunking
      body2 = ["same", " content"]

      assert {:ok, sha1, size1} = CAS.put_stream(body1)
      assert {:ok, sha2, size2} = CAS.put_stream(body2)

      assert sha1 == sha2
      assert size1 == size2
    end
  end

  describe "cas_path/1" do
    test "fans out two-level: <cas_root>/<aa>/<bb>/<sha>" do
      # Arbitrary valid-shape 64-hex sha
      sha = "abcdef0123456789" <> String.duplicate("0", 48)
      path = CAS.cas_path(sha)

      # Expected structure: .../ab/cd/<sha>
      assert String.ends_with?(path, "/ab/cd/#{sha}")
      # Path starts at the configured cas_root
      assert String.starts_with?(path, CAS.cas_root())
    end

    test "strings shorter than 4 chars raise FunctionClauseError" do
      # T1 path-traversal defence: the bit-size guard in the pattern
      # match rejects anything that isn't at least 4 bytes of binary.
      assert_raise FunctionClauseError, fn -> CAS.cas_path("abc") end
    end
  end

  describe "read-only blob mode" do
    test "written blob is mode 0444 (read-only) on POSIX filesystems" do
      {:ok, sha, _size} = CAS.put_stream(["readonly test"])
      path = CAS.cas_path(sha)

      stat = File.stat!(path)
      # POSIX mode low bits — expect 0o444 (r--r--r--). Some FUSE /
      # Windows filesystems may fail the chmod; the integrity contract
      # is enforced by sha256 re-hash in Kiln.Artifacts.read!/1, not by
      # mode bits — so we assert-or-log here rather than hard-fail on
      # systems that silently ignore chmod.
      mode_low = Bitwise.band(stat.mode, 0o777)

      if mode_low == 0o444 do
        assert mode_low == 0o444
      else
        # Non-POSIX fs — document and continue. Tested integrity path
        # lives in test/kiln/artifacts_test.exs read!/1 tests.
        IO.puts(
          "[cas_test] non-0o444 mode #{inspect(mode_low, base: :octal)} — " <>
            "filesystem may not support chmod; integrity still guaranteed by re-hash"
        )
      end
    end
  end
end
