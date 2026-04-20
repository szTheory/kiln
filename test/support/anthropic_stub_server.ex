defmodule Kiln.AnthropicStubServer do
  @moduledoc """
  Bypass-based stub of the Anthropic Messages API (see
  `docs.anthropic.com/en/api/messages`). Bound to a dynamic localhost
  port so multiple tests can spin up independent stubs under async
  ExUnit; callers configure the adapter with
  `base_url: "http://localhost:\#{stub.port}"`.

  This is the unit/contract-test substitute for a live Anthropic
  round-trip — it exists so `mix test` can exercise the adapter's
  request shape / response parsing / retry behaviour without burning a
  PAT token (SEC-01 gate). Live-provider tests are tagged
  `@tag :live_anthropic` and excluded by default.

  ## Usage

      stub = Kiln.AnthropicStubServer.start!()

      Bypass.expect(stub.bypass, "POST", "/v1/messages", fn conn ->
        Plug.Conn.resp(
          conn,
          200,
          Jason.encode!(Kiln.AnthropicStubServer.ok_response())
        )
      end)

      {:ok, response} =
        Kiln.Agents.Adapter.Anthropic.complete(prompt,
          base_url: stub.base_url
        )

  ## Canned responses

    * `ok_response/0` — 200 response with `stop_reason: "end_turn"` and
      a 10-in/5-out usage record.
    * `rate_limit_response/0` — 429-shape error body. Callers still
      control the HTTP status via `Plug.Conn.resp/3`.
    * Context-length / content-policy / 5xx shapes live under
      `test/support/fixtures/anthropic_responses/*.json` and are loaded
      directly by tests that need them.
  """

  defstruct [:bypass, :port, :base_url]

  @type t :: %__MODULE__{
          bypass: term(),
          port: pos_integer(),
          base_url: String.t()
        }

  @spec start!() :: t()
  def start! do
    bypass = Bypass.open()

    %__MODULE__{
      bypass: bypass,
      port: bypass.port,
      base_url: "http://localhost:#{bypass.port}"
    }
  end

  @spec ok_response() :: map()
  def ok_response do
    %{
      "id" => "msg_01ABC",
      "type" => "message",
      "role" => "assistant",
      "model" => "claude-sonnet-4-5-20250929",
      "content" => [%{"type" => "text", "text" => "ok"}],
      "stop_reason" => "end_turn",
      "stop_sequence" => nil,
      "usage" => %{
        "input_tokens" => 10,
        "output_tokens" => 5,
        "cache_read_input_tokens" => 0,
        "cache_creation_input_tokens" => 0
      }
    }
  end

  @spec rate_limit_response() :: map()
  def rate_limit_response do
    %{
      "type" => "error",
      "error" => %{
        "type" => "rate_limit_error",
        "message" => "Number of requests has exceeded your rate limit"
      }
    }
  end
end
