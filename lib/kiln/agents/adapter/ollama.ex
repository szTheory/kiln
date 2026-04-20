defmodule Kiln.Agents.Adapter.Ollama do
  @moduledoc """
  SCAFFOLDED Ollama (local) adapter (D-101). No API key — connects to
  `OLLAMA_HOST` env var (default `http://localhost:11434`). Most CI
  runners do not have Ollama running, so tests are gated on
  `@tag :live_ollama` (excluded from `mix test` by default).

  Ollama's `capabilities/0` flips `json_schema_mode: false` — the
  `Kiln.Agents.StructuredOutput` facade falls through to the
  prompted-JSON + JSV post-validate + 1 retry path when this adapter
  is selected (D-104).

  No `Kiln.Secrets.reveal!/1` call in this file — Ollama is
  local/unauthenticated by design.
  """

  @behaviour Kiln.Agents.Adapter

  alias Kiln.Agents.{Prompt, Response}

  @impl true
  def capabilities do
    %{
      streaming: true,
      tools: false,
      thinking: false,
      vision: false,
      json_schema_mode: false
    }
  end

  @impl true
  def complete(%Prompt{} = _prompt, _opts), do: {:error, :scaffolded}

  @impl true
  def stream(%Prompt{} = _prompt, _opts), do: {:error, :scaffolded}

  @impl true
  def count_tokens(%Prompt{messages: messages}) do
    rough =
      messages
      |> Enum.map(&char_len/1)
      |> Enum.sum()

    {:ok, div(rough, 4) + 1}
  end

  defp char_len(%{content: content}), do: content |> to_string() |> String.length()
  defp char_len(_), do: 0

  # Elide unused-alias warnings if future extensions need Response.
  @typedoc false
  @type _response :: Response.t()
end
