defmodule Kiln.Secrets.Ref do
  @moduledoc """
  A reference to a named secret held in `:persistent_term`. Raw string
  values NEVER appear on this struct — the `name` atom is resolved to
  the raw string only via `Kiln.Secrets.reveal!/1` inside the adapter's
  HTTP-call stack frame (D-132 / D-133 Layer 1).

  `@derive {Inspect, except: [:name]}` protects the field from the
  default struct printer; the custom `defimpl Inspect, for: Kiln.Secrets.Ref`
  below renders as `#Secret<name>` so grep audits see a stable shape
  and no accidental leak of the wrapping `%Kiln.Secrets.Ref{...}`
  module path in log output.

  This is D-133 Layer 2 (Elixir `@derive Inspect` boundary) of the
  six-layer redaction defense:

    * Layer 1 — type-system boundary via `Kiln.Secrets.reveal!/1`
    * Layer 2 — `%Ref{}` struct + custom Inspect impl (this module)
    * Layer 3 — `Ecto.Schema` `field :api_key_reference, :string, redact: true`
    * Layer 4 — `LoggerJSON.Redactor` implementation `Kiln.Logging.SecretRedactor`
    * Layer 5 — `Ecto.Changeset` `redact_fields/2` on error rendering
    * Layer 6 — adversarial docker-inspect + log-scan tests (Wave 6)

  Layers 1, 2, 4 land in plan 03-01; Layer 3 + 5 are applied by
  downstream Ecto schemas; Layer 6 is the adversarial-corpus suite.
  """

  @derive {Inspect, except: [:name]}
  defstruct [:name]

  @type t :: %__MODULE__{name: atom()}
end

defimpl Inspect, for: Kiln.Secrets.Ref do
  def inspect(%Kiln.Secrets.Ref{name: name}, _opts) do
    "#Secret<#{name}>"
  end
end
