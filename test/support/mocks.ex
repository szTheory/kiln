# Phase 3 Wave 0 — Mox defmock registry.
#
# `test/support/` is an `elixirc_paths(:test)` entry, so this file is
# compiled once at `mix compile` time. `test_helper.exs` then issues a
# `Code.require_file("support/mocks.ex", __DIR__)` as a belt-and-braces
# "make sure the defmocks are loaded before ExUnit.start/1" step. The
# whole body below is wrapped in a single `unless Code.ensure_loaded?/1`
# so the second loader (require_file) short-circuits — no "redefining
# module" warnings under `--warnings-as-errors`.
#
# See `Kiln.TestMocks` @moduledoc for the registry contract and the
# deferred-activation pattern that supports Wave 0 (no behaviour modules
# yet) compiling cleanly while Wave 2/4 (behaviours land) auto-activate
# real Mox defmocks on next compile.

unless Code.ensure_loaded?(Kiln.TestMocks) do
  defmodule Kiln.TestMocks do
    @moduledoc """
    Central registry of Mox defmocks for Phase 3. Loaded by `test_helper.exs`
    via `Code.require_file/2` **before** `ExUnit.start/1` so every test module
    sees the mocks at compile + run time.

    Mocks registered at module-load time:

      * `Kiln.Agents.AdapterMock` — stand-in for any `Kiln.Agents.Adapter`
        behaviour implementation (live Anthropic, OpenAI, Google, Ollama,
        or scaffolded modules). Wave 2 (plan 03-05) ships the behaviour
        contract itself.
      * `Kiln.Sandboxes.DriverMock` — stand-in for any
        `Kiln.Sandboxes.Driver` behaviour implementation (DockerDriver is
        the sole concrete impl in v1). Wave 4 (plan 03-08) ships the
        behaviour contract itself.

    ## Deferred-activation pattern

    `Mox.defmock/2` (Mox 1.2) invokes `Code.ensure_compiled!/1` on its
    `for:` target at **defmock time**, not at first-call time. In Wave 0
    the behaviour modules do not yet exist, so each `Mox.defmock` call
    below is gated on `Code.ensure_loaded?/1`. When the target behaviour
    is absent, we register a bare placeholder `defmodule` with an
    `__deferred__/0` marker so tests can assert the mock name resolves
    and detect the scaffold state.

    Wave 2 and Wave 4 plans land the real behaviour modules; on the next
    `mix compile`, the `Code.ensure_loaded?/1` branch flips and the
    `Mox.defmock/2` call runs, re-defining the mock with the real
    behaviour callbacks. The mock name (`Kiln.Agents.AdapterMock` /
    `Kiln.Sandboxes.DriverMock`) remains stable across the transition so
    tests authored in Wave 2/4 compile unchanged.

    Mirrors the deferred-activation pattern established by
    `Kiln.StuckDetectorCase` (Phase 2) and `Kiln.FactoryCircuitBreakerCase`
    (this wave).
    """

    @doc """
    Creates a placeholder module that stands in for a Mox mock whose
    target behaviour is not yet compiled. The placeholder exposes
    `__deferred__/0` so tests can detect the scaffold state.
    """
    @spec define_placeholder!(module()) :: :ok
    def define_placeholder!(mock_name) when is_atom(mock_name) do
      Module.create(
        mock_name,
        quote do
          @moduledoc false
          def __mock__?, do: true
          def __deferred__, do: true
        end,
        Macro.Env.location(__ENV__)
      )

      :ok
    end

    @doc """
    Promote a deferred placeholder to a real Mox defmock once the
    target behaviour exists.
    """
    @spec ensure_mock!(module(), module()) :: :ok
    def ensure_mock!(mock_name, behaviour) when is_atom(mock_name) and is_atom(behaviour) do
      deferred? =
        Code.ensure_loaded?(mock_name) and function_exported?(mock_name, :__deferred__, 0)

      if deferred? and Code.ensure_loaded?(behaviour) do
        :code.purge(mock_name)
        :code.delete(mock_name)
      end

      cond do
        Code.ensure_loaded?(mock_name) ->
          :ok

        Code.ensure_loaded?(behaviour) ->
          Mox.defmock(mock_name, for: behaviour)
          :ok

        true ->
          define_placeholder!(mock_name)
      end
    end
  end
end

# Defmocks execute at module-load time. This block is intentionally
# outside the `Kiln.TestMocks` definition guard so `Code.require_file`
# can promote a deferred placeholder to a real Mox defmock once the
# target behaviour exists on a later compile.
Kiln.TestMocks.ensure_mock!(Kiln.Agents.AdapterMock, Kiln.Agents.Adapter)
Kiln.TestMocks.ensure_mock!(Kiln.Sandboxes.DriverMock, Kiln.Sandboxes.Driver)
