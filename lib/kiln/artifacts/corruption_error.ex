defmodule Kiln.Artifacts.CorruptionError do
  @moduledoc """
  Raised by `Kiln.Artifacts.read!/1` when a CAS blob's re-hashed SHA-256
  does not match the `artifacts.sha256` recorded at put-time (D-84).

  This is the loud end of the durability-floor integrity contract:
  Kiln never silently returns corrupted bytes. The audit ledger receives
  an `:integrity_violation` event *before* this exception is raised, so
  a forensic record of the mismatch exists even if the caller's rescue
  handler swallows the exception.

  Fields:

    * `:artifact_id` — the `artifacts.id` UUID whose sha256 mismatched.
    * `:expected` — the 64-hex sha recorded at put-time (from the row).
    * `:actual` — the 64-hex sha re-computed at read time.
    * `:path` — the on-disk CAS path that was re-hashed.
    * `:message` — human-readable summary; see `exception/1` below.
  """

  defexception [:artifact_id, :expected, :actual, :path, :message]

  @type t :: %__MODULE__{
          artifact_id: Ecto.UUID.t() | nil,
          expected: String.t() | nil,
          actual: String.t() | nil,
          path: String.t() | nil,
          message: String.t() | nil
        }

  @impl true
  def exception(fields) do
    fields = Keyword.new(fields)
    expected = Keyword.get(fields, :expected, "<nil>")
    actual = Keyword.get(fields, :actual, "<nil>")
    artifact_id = Keyword.get(fields, :artifact_id, "<nil>")

    msg =
      "artifact corruption detected: artifact_id=#{artifact_id} expected=#{expected} actual=#{actual}"

    struct!(__MODULE__, Keyword.put(fields, :message, msg))
  end
end
