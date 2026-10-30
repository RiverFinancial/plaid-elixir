defmodule Plaid.ResponseTest do
  use ExUnit.Case, async: true

  import Mox

  setup :verify_on_exit!

  test "retains the decoded body alongside the mapped endpoint result" do
    bypass = Bypass.open()
    body = Plaid.Factory.http_response_body(:accounts) |> Map.put("new_field", %{"value" => 7})

    Bypass.expect(bypass, "POST", "/accounts/get", fn conn ->
      conn
      |> Plug.Conn.put_resp_header("content-type", "application/json")
      |> Plug.Conn.resp(200, JSON.encode!(body))
    end)

    assert %Plaid.Response{
             result: {:ok, %Plaid.Accounts{} = accounts},
             body: ^body,
             status: 200
           } = Plaid.Accounts.get(%{access_token: "access-sandbox-test"}, config(bypass))

    assert [%Plaid.Accounts.Account{} | _] = accounts.accounts
    assert Map.has_key?(accounts, :new_field) == false
  end

  test "retains an unsuccessful HTTP response and its ordinary error result" do
    bypass = Bypass.open()
    body = Plaid.Factory.http_response_body(:error) |> Map.put("new_error_detail", "detail")

    Bypass.expect(bypass, "POST", "/user_account/session/get", fn conn ->
      conn
      |> Plug.Conn.put_resp_header("content-type", "application/json")
      |> Plug.Conn.resp(400, JSON.encode!(body))
    end)

    assert %Plaid.Response{
             result: {:error, %Plaid.Error{http_code: 400}},
             body: ^body,
             status: 400
           } =
             Plaid.Layer.get_user_account_session(%{public_token: "public-test"}, config(bypass))
  end

  test "retains non-JSON HTTP errors" do
    bypass = Bypass.open()

    Bypass.expect(bypass, "POST", "/link/token/get", fn conn ->
      conn
      |> Plug.Conn.put_resp_header("content-type", "text/html")
      |> Plug.Conn.resp(502, "upstream unavailable")
    end)

    assert %Plaid.Response{
             result: {:error, %Plaid.Error{http_code: 502}},
             body: "upstream unavailable",
             status: 502
           } = Plaid.Link.get_link_token(%{link_token: "link-test"}, config(bypass))
  end

  test "retains transport errors without inventing an HTTP response" do
    config = %{
      client: PlaidMock,
      client_id: "test_id",
      secret: "test_secret",
      root_uri: "http://localhost/",
      response_mode: :full,
      telemetry_metadata: %{user_id: 123}
    }

    PlaidMock
    |> expect(:send_request, fn request, _client ->
      assert request.opts.metadata.user_id == 123
      assert request.opts.metadata.path == "session/token/create"
      {:error, :econnrefused}
    end)
    |> expect(:handle_response, &Plaid.handle_response/2)

    assert %Plaid.Response{result: {:error, :econnrefused}, body: nil, status: nil} =
             Plaid.Layer.create_session_token(%{}, config)
  end

  defp config(bypass) do
    %{
      client_id: "test_id",
      secret: "test_secret",
      root_uri: "http://localhost:#{bypass.port}/",
      response_mode: :full
    }
  end
end
