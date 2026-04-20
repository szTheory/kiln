defmodule Kiln.Secrets do
  @moduledoc """
  Reference-only secret store over `:persistent_term` (D-131).

  Semantics:

    * `put/2` — writes at boot via `config/runtime.exs`. Write-once at
      boot (no runtime mutation) per D-131 to avoid global GC thrash.
      A `nil` value `erase`s the slot (used by test cleanup and by the
      `ModelRegistry` missing-provider escape path).
    * `get!/1` — returns `%Kiln.Secrets.Ref{}` only. Raises `ArgumentError`
      (from `:persistent_term.get/1`) if the secret was never `put/2`.
    * `get/1` — non-raising variant; returns `{:ok, %Ref{}}` or `:error`.
    * `present?/1` — `true` iff `:persistent_term` has a non-nil value
      for `{Kiln.Secrets, name}`.
    * `reveal!/1` — the SOLE raw-string reveal path. Takes either a
      `%Ref{}` or a bare atom name. Raises `ArgumentError` on missing.

  **Grep audit target:** Phase 3 ships exactly 3 `Kiln.Secrets.reveal!/1`
  call sites — one per live-ish provider adapter's HTTP-call function
  (`Kiln.Agents.Adapter.Anthropic.call_http/2`, `.OpenAI.call_http/2`,
  `.Google.call_http/2`). Ollama scaffolded adapter is local, no key.

  D-133 Layer 1 (type-system boundary): raw string ONLY crosses the
  function-stack-frame boundary of `reveal!/1`.
  """

  alias Kiln.Secrets.Ref

  @doc """
  Stores a secret in `:persistent_term` under `{Kiln.Secrets, name}`.

  Passing `nil` erases the slot (test cleanup / operator rotation).
  Writes are meant to happen at boot only — see `config/runtime.exs`.
  """
  @spec put(atom(), binary() | nil) :: :ok
  def put(name, nil) when is_atom(name) do
    _ = :persistent_term.erase({__MODULE__, name})
    :ok
  end

  def put(name, value) when is_atom(name) and is_binary(value) do
    :persistent_term.put({__MODULE__, name}, value)
    :ok
  end

  @doc """
  Returns a `%Kiln.Secrets.Ref{}` for the named secret.

  Raises `ArgumentError` if the secret was never `put/2` — fail loudly
  rather than silently returning nil (CLAUDE.md convention).
  """
  @spec get!(atom()) :: Ref.t()
  def get!(name) when is_atom(name) do
    # Reach into :persistent_term with no default so an absent key
    # triggers the built-in ArgumentError. The read result is
    # discarded — raw strings never escape a stack frame other than
    # `reveal!/1`'s.
    _ = :persistent_term.get({__MODULE__, name})
    %Ref{name: name}
  end

  @doc """
  Non-raising variant of `get!/1`. Returns `{:ok, %Ref{}}` when the
  secret is present, `:error` otherwise.
  """
  @spec get(atom()) :: {:ok, Ref.t()} | :error
  def get(name) when is_atom(name) do
    case :persistent_term.get({__MODULE__, name}, :__absent__) do
      :__absent__ -> :error
      _ -> {:ok, %Ref{name: name}}
    end
  end

  @doc """
  `true` iff a non-nil secret value is present under `name`.

  Used by boot-time provider-availability checks and by the
  `ModelRegistry` missing-provider escape path.
  """
  @spec present?(atom()) :: boolean()
  def present?(name) when is_atom(name) do
    :persistent_term.get({__MODULE__, name}, nil) != nil
  end

  @doc """
  Resolves a reference (or bare atom name) to the raw secret string.

  D-133 Layer 1 — this is the SOLE call that produces a raw string;
  every adapter HTTP-call function is grep-audited for exactly one
  `Kiln.Secrets.reveal!/1` site.

  Raises `ArgumentError` if the secret was never `put/2`.
  """
  @spec reveal!(Ref.t() | atom()) :: binary()
  def reveal!(%Ref{name: name}), do: reveal!(name)

  def reveal!(name) when is_atom(name) do
    :persistent_term.get({__MODULE__, name})
  end
end
