defmodule Plaid.LinkTest do
  use ExUnit.Case, async: true

  import Mox
  import Plaid.Factory

  setup do
    verify_on_exit!()

    {:ok,
     params: %{access_token: "my-token"},
     config: %{
       client: PlaidMock,
       client_id: "test_id",
       secret: "test_secret",
       root_uri: "http://localhost:4000/"
     }}
  end

  @moduletag :link

  @tag :unit
  test "link data structure encodes with Jason" do
    assert {:ok, _} = Jason.encode(%Plaid.Link{metadata: %Plaid.Link.Metadata{}})
  end

  describe "link create_link_token/2" do
    @tag :unit
    test "submits request and unmarshalls response", %{params: params, config: config} do
      PlaidMock
      |> expect(:send_request, fn request, _client ->
        assert request.method == :post
        assert request.endpoint == "link/token/create"
        assert %{metadata: _} = request.opts
        {:ok, %Tesla.Env{}}
      end)
      |> expect(:handle_response, fn _response, mapper ->
        body = http_response_body(:create_link_token)
        {:ok, mapper.(body)}
      end)

      assert {:ok, ds} = Plaid.Link.create_link_token(params, config)
      assert Plaid.Link == ds.__struct__
      assert Plaid.Link.Metadata == ds.metadata.__struct__
      assert ds.link_sessions == nil
    end

    @tag :integration
    test "success integration test", %{params: params} do
      bypass = Bypass.open()

      config = %{
        client_id: "test_id",
        secret: "test_secret",
        root_uri: "http://localhost:#{bypass.port}/"
      }

      body = http_response_body(:create_link_token)

      Bypass.expect(bypass, fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(200, JSON.encode!(body))
      end)

      assert {:ok, %Plaid.Link{}} = Plaid.Link.create_link_token(params, config)
    end

    @tag :integration
    test "error integration test", %{params: params} do
      bypass = Bypass.open()

      config = %{
        client_id: "test_id",
        secret: "test_secret",
        root_uri: "http://localhost:#{bypass.port}/"
      }

      body = http_response_body(:error)

      Bypass.expect(bypass, fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(400, JSON.encode!(body))
      end)

      assert {:error, %Plaid.Error{}} = Plaid.Link.create_link_token(params, config)
    end
  end

  describe "link get_link_token/2" do
    @tag :unit
    test "submits request and unmarshalls response", %{params: params, config: config} do
      PlaidMock
      |> expect(:send_request, fn request, _client ->
        assert request.method == :post
        assert request.endpoint == "link/token/get"
        assert %{metadata: _} = request.opts
        {:ok, %Tesla.Env{}}
      end)
      |> expect(:handle_response, fn _response, mapper ->
        body = http_response_body(:get_link_token)
        {:ok, mapper.(body)}
      end)

      assert {:ok, ds} = Plaid.Link.get_link_token(params, config)
      assert Plaid.Link == ds.__struct__
      assert Plaid.Link.Metadata == ds.metadata.__struct__

      assert [%Plaid.Link.Session{} = session] = ds.link_sessions
      assert session.link_session_id == "356dbb28-7f98-44d1-8e6d-0cec580f3171"
      assert session.started_at == "2020-03-26T12:57:00Z"
      assert session.finished_at == "2020-03-26T12:58:00Z"
      assert session.on_success == nil
      assert session.on_exit == nil

      assert %Plaid.Link.Session.Exit{error: %{"error_code" => "INVALID_CREDENTIALS"}} =
               session.exit

      assert session.exit.metadata["status"] == "requires_credentials"

      assert [%Plaid.Link.Session.Event{} = select, %Plaid.Link.Session.Event{} = error] =
               session.events

      assert select.event_name == "SELECT_INSTITUTION"
      assert select.event_id == "7a3f1b2c-0d4e-4f5a-9b6c-1d2e3f4a5b6c"
      assert select.timestamp == "2020-03-26T12:57:05Z"
      assert %Plaid.Link.Session.Event.Metadata{} = select.event_metadata
      assert select.event_metadata.institution_id == "ins_3"
      assert select.event_metadata.institution_name == "Chase"
      assert select.event_metadata.institution_search_query == "chase"
      assert select.event_metadata.view_name == "SELECT_INSTITUTION"
      assert select.event_metadata.error_code == nil
      assert error.event_metadata.error_code == "INVALID_CREDENTIALS"
      assert error.event_metadata.error_type == "ITEM_ERROR"
      assert error.event_metadata.mfa_type == "code"
      assert error.event_metadata.routing_number == "021000021"
      assert error.event_metadata.account_number_mask == "0000"

      assert %Plaid.Link.Session.Results{} = session.results

      assert [%Plaid.Link.Session.ItemAddResult{} = item_add] =
               session.results.item_add_results

      assert item_add.public_token == "public-sandbox-5c224a01-8314-4491-a06f-39e193d5cddc"
      assert [%{"mask" => "0000"}] = item_add.accounts
      assert item_add.institution["institution_id"] == "ins_3"
      assert session.results.bank_income_results == []
      assert session.results.document_income_results == nil
    end

    @tag :integration
    test "success integration test", %{params: params} do
      bypass = Bypass.open()

      config = %{
        client_id: "test_id",
        secret: "test_secret",
        root_uri: "http://localhost:#{bypass.port}/"
      }

      body = http_response_body(:get_link_token)

      Bypass.expect(bypass, fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(200, JSON.encode!(body))
      end)

      assert {:ok, %Plaid.Link{}} = Plaid.Link.get_link_token(params, config)
    end

    @tag :integration
    test "error integration test", %{params: params} do
      bypass = Bypass.open()

      config = %{
        client_id: "test_id",
        secret: "test_secret",
        root_uri: "http://localhost:#{bypass.port}/"
      }

      body = http_response_body(:error)

      Bypass.expect(bypass, fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(400, JSON.encode!(body))
      end)

      assert {:error, %Plaid.Error{}} = Plaid.Link.get_link_token(params, config)
    end
  end

  test "keeps absent, null and empty session results", %{config: config} do
    body =
      :get_link_token
      |> Plaid.Factory.http_response_body()
      |> Map.put("link_sessions", [
        %{"link_session_id" => "absent"},
        %{"link_session_id" => "null", "results" => nil, "events" => nil, "exit" => nil},
        %{"link_session_id" => "empty", "events" => [], "results" => %{"item_add_results" => []}}
      ])

    PlaidMock
    |> expect(:send_request, fn _request, _client -> {:ok, %Tesla.Env{}} end)
    |> expect(:handle_response, fn _response, mapper -> {:ok, mapper.(body)} end)

    assert {:ok, %Plaid.Link{link_sessions: [absent, null, empty]}} =
             Plaid.Link.get_link_token(%{link_token: "link-test"}, config)

    assert absent.results == nil
    assert absent.events == nil
    assert null.results == nil
    assert null.events == nil
    assert null.exit == nil
    assert empty.events == []
    assert empty.results.item_add_results == []
  end
end
