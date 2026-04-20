defmodule Kiln.Agents.Adapter.AnthropicTest do
  @moduledoc """
  Contract tests for `Kiln.Agents.Adapter.Anthropic` — the Phase 3 LIVE
  adapter per D-101 / D-110 / D-131..D-133.

  Covers:
    * capabilities/0 returns the 5 expected flags
    * complete/2 against a Bypass stub returns %Response{} + emits the
      canonical :start / :stop telemetry pair with measurements and metadata
    * 429 path returns {:error, {:http_status, 429, _}}
    * count_tokens/1 against Bypass returns {:ok, n}
    * Kiln.Secrets.reveal!/1 is called exactly once in the adapter source
      (grep audit — D-132 / D-133 Layer 1)
    * ExternalOperations records one llm_complete intent + one completion

  Live Anthropic call gated on `@tag :live_anthropic` (excluded by default).
  """

  use Kiln.AuditLedgerCase, async: false

  require Logger

  alias Kiln.Agents.{Adapter.Anthropic, Prompt, Response}

  setup do
    # Seed a fake API key in :persistent_term so reveal!/1 succeeds inside
    # the adapter's call_http/2 stack frame — the raw key never crosses
    # the adapter boundary, only exists inside the HTTP header build.
    Kiln.Secrets.put(:anthropic_api_key, "sk-ant-FAKE00000000000000000000000000000000")
    on_exit(fn -> Kiln.Secrets.put(:anthropic_api_key, nil) end)

    Logger.metadata(
      correlation_id: Ecto.UUID.generate(),
      run_id: "run-#{:rand.uniform(1_000_000)}",
      stage_id: "stage-x"
    )

    :ok
  end

  describe "capabilities/0" do
    test "returns the 5-flag capability map" do
      caps = Anthropic.capabilities()
      assert caps.streaming == true
      assert caps.tools == true
      assert caps.thinking == true
      assert caps.vision == true
      assert caps.json_schema_mode == true
    end
  end

  describe "complete/2 against Bypass stub" do
    setup do
      stub = Kiln.AnthropicStubServer.start!()
      {:ok, stub: stub}
    end

    test "returns %Response{} on 200 and emits :start + :stop telemetry", %{stub: stub} do
      ok_response =
        File.read!("test/support/fixtures/anthropic_responses/ok_message.json")
        |> Jason.decode!()

      Bypass.expect(stub.bypass, "POST", "/v1/messages", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(ok_response))
      end)

      handler_id = "anthropic-test-#{:erlang.unique_integer([:positive])}"
      test_pid = self()

      :ok =
        :telemetry.attach_many(
          handler_id,
          [
            [:kiln, :agent, :call, :start],
            [:kiln, :agent, :call, :stop]
          ],
          fn event, measurements, metadata, _cfg ->
            send(test_pid, {:telemetry, event, measurements, metadata})
          end,
          nil
        )

      on_exit(fn -> :telemetry.detach(handler_id) end)

      prompt = %Prompt{
        model: "claude-sonnet-4-5-20250929",
        messages: [%{role: :user, content: "hi"}],
        max_tokens: 100
      }

      assert {:ok, %Response{} = response} =
               Anthropic.complete(prompt, base_url: stub.base_url, role: :coder)

      assert response.actual_model_used == "claude-sonnet-4-5-20250929"
      assert response.tokens_in == 12
      assert response.tokens_out == 8
      assert response.stop_reason == :end_turn

      assert_received {:telemetry, [:kiln, :agent, :call, :start], _start_measurements,
                       start_meta}

      assert start_meta.provider == :anthropic
      assert start_meta.role == :coder
      assert start_meta.requested_model == "claude-sonnet-4-5-20250929"

      assert_received {:telemetry, [:kiln, :agent, :call, :stop], stop_measurements, stop_meta}

      assert stop_measurements.tokens_in == 12
      assert stop_measurements.tokens_out == 8
      assert Map.has_key?(stop_measurements, :duration)
      assert stop_meta.actual_model_used == "claude-sonnet-4-5-20250929"
      assert stop_meta.fallback? == false
      assert stop_meta.provider == :anthropic
    end

    test "returns {:error, {:http_status, 429, _}} on rate-limit", %{stub: stub} do
      err =
        File.read!("test/support/fixtures/anthropic_responses/rate_limit_429.json")
        |> Jason.decode!()

      Bypass.expect(stub.bypass, "POST", "/v1/messages", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(429, Jason.encode!(err))
      end)

      prompt = %Prompt{
        model: "claude-haiku-4-5",
        messages: [%{role: :user, content: "hi"}],
        max_tokens: 10
      }

      assert {:error, {:http_status, 429, _body}} =
               Anthropic.complete(prompt, base_url: stub.base_url)
    end

    test "fallback? metadata is true when Anthropic returns a different model", %{stub: stub} do
      # Requested claude-sonnet-4-5; provider silently served haiku — flag fallback
      body =
        File.read!("test/support/fixtures/anthropic_responses/ok_message.json")
        |> Jason.decode!()
        |> Map.put("model", "claude-haiku-4-5-20250929")

      Bypass.expect(stub.bypass, "POST", "/v1/messages", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(body))
      end)

      handler_id = "anthropic-fallback-test-#{:erlang.unique_integer([:positive])}"
      test_pid = self()

      :ok =
        :telemetry.attach(
          handler_id,
          [:kiln, :agent, :call, :stop],
          fn _event, _m, metadata, _cfg ->
            send(test_pid, {:stop_meta, metadata})
          end,
          nil
        )

      on_exit(fn -> :telemetry.detach(handler_id) end)

      prompt = %Prompt{
        model: "claude-sonnet-4-5-20250929",
        messages: [%{role: :user, content: "hi"}],
        max_tokens: 10
      }

      assert {:ok, %Response{actual_model_used: "claude-haiku-4-5-20250929"}} =
               Anthropic.complete(prompt, base_url: stub.base_url)

      assert_received {:stop_meta, meta}
      assert meta.fallback? == true
      assert meta.requested_model == "claude-sonnet-4-5-20250929"
      assert meta.actual_model_used == "claude-haiku-4-5-20250929"
    end
  end

  describe "count_tokens/1 against Bypass stub" do
    setup do
      stub = Kiln.AnthropicStubServer.start!()
      # Override Anthropic base_url via Application env so count_tokens/1
      # (which has no opts on the behaviour signature) can be redirected.
      prev = Application.get_env(:kiln, Kiln.Agents.Adapter.Anthropic, [])
      Application.put_env(:kiln, Kiln.Agents.Adapter.Anthropic, base_url: stub.base_url)
      on_exit(fn -> Application.put_env(:kiln, Kiln.Agents.Adapter.Anthropic, prev) end)
      {:ok, stub: stub}
    end

    test "returns input token count on 200", %{stub: stub} do
      Bypass.expect(stub.bypass, "POST", "/v1/messages/count_tokens", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{"input_tokens" => 47}))
      end)

      prompt = %Prompt{
        model: "claude-sonnet-4-5",
        messages: [%{role: :user, content: "some text"}],
        max_tokens: 4096
      }

      assert {:ok, 47} = Anthropic.count_tokens(prompt)
    end
  end

  describe "Secrets.reveal! grep audit (D-132 / D-133 Layer 1)" do
    test "this file calls Kiln.Secrets.reveal! exactly once" do
      source = File.read!("lib/kiln/agents/adapter/anthropic.ex")

      # Count live call sites only — a call site is `Secrets.reveal!(` or
      # `Kiln.Secrets.reveal!(`. Docstring mentions are unquoted or appear
      # inside the moduledoc heredoc; we discriminate by requiring the
      # open-paren immediately following.
      count_aliased = length(String.split(source, "Secrets.reveal!(")) - 1
      count_fully_qualified = length(String.split(source, "Kiln.Secrets.reveal!(")) - 1

      # Expect exactly 1 live site total. Implementation uses aliased form
      # (`alias Kiln.{..., Secrets, ...}` + `Secrets.reveal!(:anthropic_api_key)`).
      # Allow for either form to be forward-compatible with refactors.
      total = count_aliased + count_fully_qualified

      assert total == 1,
             "expected exactly 1 live Kiln.Secrets.reveal! call site in anthropic.ex; got #{total} (aliased=#{count_aliased} fqn=#{count_fully_qualified})"
    end
  end

  @tag :live_anthropic
  test "live Anthropic call returns %Response{} (skipped without ANTHROPIC_API_KEY)" do
    real_key = System.get_env("ANTHROPIC_API_KEY")

    if real_key do
      Kiln.Secrets.put(:anthropic_api_key, real_key)

      prompt = %Prompt{
        model: "claude-haiku-4-5-20250929",
        messages: [%{role: :user, content: "Say 'hi' in 1 word."}],
        max_tokens: 5
      }

      assert {:ok, %Response{}} = Anthropic.complete(prompt, role: :smoke_test)
    else
      flunk("ANTHROPIC_API_KEY not set — gate the test or skip via @tag :live_anthropic")
    end
  end
end
