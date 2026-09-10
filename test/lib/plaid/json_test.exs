defmodule Plaid.JSONTest do
  use ExUnit.Case, async: true

  alias Plaid.Client
  alias Plaid.Client.Request

  setup do
    bypass = Bypass.open()

    client =
      Client.new(%{
        root_uri: "http://localhost:#{bypass.port}/",
        client_id: "test-client",
        secret: "test-secret"
      })

    {:ok, bypass: bypass, client: client}
  end

  test "encodes request values without changing their JSON meaning", %{
    bypass: bypass,
    client: client
  } do
    Bypass.expect_once(bypass, "POST", "/example", fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert Jason.decode!(body) == %{
               "text" => "café 🐕\n\"quoted\"",
               "integer" => 9_007_199_254_740_993,
               "float" => 12.25,
               "nested" => %{"values" => [true, false, nil]},
               "date" => "2026-01-02"
             }

      conn
      |> Plug.Conn.put_resp_header("content-type", "application/json")
      |> Plug.Conn.resp(200, ~s({"ok":true}))
    end)

    request = %Request{
      method: :post,
      endpoint: "example",
      body: %{
        text: "café 🐕\n\"quoted\"",
        integer: 9_007_199_254_740_993,
        float: 12.25,
        nested: %{values: [true, false, nil]},
        date: ~D[2026-01-02]
      }
    }

    assert {:ok, %Tesla.Env{status: 200, body: %{"ok" => true}}} =
             Plaid.send_request(request, client)
  end

  test "decodes JSON scalars, arrays, and Unicode with string keys", %{
    bypass: bypass,
    client: client
  } do
    Bypass.expect_once(bypass, fn conn ->
      conn
      |> Plug.Conn.put_resp_header("content-type", "application/json; charset=utf-8")
      |> Plug.Conn.resp(
        200,
        ~S({"text":"caf\u00e9 \ud83d\udc15","integer":9007199254740993,"float":1.25e2,"values":[null,false,true],"date":"2026-01-02"})
      )
    end)

    request = %Request{method: :post, endpoint: "example"}

    assert {:ok,
            %Tesla.Env{
              body: %{
                "text" => "café 🐕",
                "integer" => 9_007_199_254_740_993,
                "float" => 125.0,
                "values" => [nil, false, true],
                "date" => "2026-01-02"
              }
            }} = Plaid.send_request(request, client)
  end

  test "returns native decode errors inside the Tesla error envelope", %{
    bypass: bypass,
    client: client
  } do
    Bypass.expect_once(bypass, fn conn ->
      conn
      |> Plug.Conn.put_resp_header("content-type", "application/json")
      |> Plug.Conn.resp(200, ~s({"broken":))
    end)

    request = %Request{method: :post, endpoint: "example"}

    assert Plaid.send_request(request, client) ==
             {:error, {Tesla.Middleware.JSON, :decode, {:unexpected_end, 10}}}
  end

  test "rejects invalid UTF-8 in JSON responses", %{bypass: bypass, client: client} do
    Bypass.expect_once(bypass, fn conn ->
      conn
      |> Plug.Conn.put_resp_header("content-type", "application/json")
      |> Plug.Conn.resp(200, <<34, 255, 34>>)
    end)

    request = %Request{method: :post, endpoint: "example"}

    assert Plaid.send_request(request, client) ==
             {:error, {Tesla.Middleware.JSON, :decode, {:invalid_byte, 1, 255}}}
  end

  test "preserves pre-encoded requests and empty response bodies", %{
    bypass: bypass,
    client: client
  } do
    Bypass.expect_once(bypass, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      assert body == ~s({"already":"encoded"})

      conn
      |> Plug.Conn.put_resp_header("content-type", "application/json")
      |> Plug.Conn.resp(204, "")
    end)

    request = %Request{method: :post, endpoint: "example", body: ~s({"already":"encoded"})}

    assert {:ok, %Tesla.Env{status: 204, body: ""}} = Plaid.send_request(request, client)
  end

  test "preserves non-JSON response bodies", %{bypass: bypass, client: client} do
    Bypass.expect_once(bypass, fn conn ->
      conn
      |> Plug.Conn.put_resp_header("content-type", "text/plain")
      |> Plug.Conn.resp(200, "not JSON")
    end)

    request = %Request{method: :post, endpoint: "example"}
    assert {:ok, %Tesla.Env{body: "not JSON"}} = Plaid.send_request(request, client)
  end

  test "uses native encoder errors for unsupported request values", %{client: client} do
    request = %Request{method: :post, endpoint: "example", body: %{unsupported: self()}}

    assert {:error,
            {Tesla.Middleware.JSON, :encode, %Protocol.UndefinedError{protocol: JSON.Encoder}}} =
             Plaid.send_request(request, client)
  end

  test "invalid UTF-8 request strings follow the native encoder exception contract", %{
    client: client
  } do
    request = %Request{method: :post, endpoint: "example", body: %{invalid: <<255>>}}

    assert %ErlangError{original: {:invalid_byte, 255}} =
             assert_raise(ErlangError, fn -> Plaid.send_request(request, client) end)
  end
end
