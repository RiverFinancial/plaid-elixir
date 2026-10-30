defmodule Plaid.LayerTest do
  use ExUnit.Case, async: true

  import Mox
  import Plaid.Factory

  alias Plaid.Layer.SessionToken
  alias Plaid.Layer.UserAccountSession
  alias Plaid.Layer.UserAccountSession.{Identity, IdentityEditHistory, Item}
  alias Plaid.Layer.UserAccountSession.IdentityEditHistory.{EditCounts, OfficialDocument}

  @session_token_params %{
    "template_id" => "template_4uinBNe4B2x9",
    "user" => %{"client_user_id" => "user-abc"}
  }

  @user_account_session_params %{
    "public_token" => "public-sandbox-a1b2c3d4-e5f6-7890-abcd-ef1234567890"
  }

  setup do
    verify_on_exit!()

    {:ok,
     config: %{
       client: PlaidMock,
       client_id: "test_id",
       secret: "test_secret",
       root_uri: "http://localhost:4000/"
     }}
  end

  @moduletag :layer

  @tag :unit
  test "layer data structures encode with Jason" do
    assert {:ok, _} =
             Jason.encode(%SessionToken{link: %SessionToken.Link{}})

    assert {:ok, _} =
             Jason.encode(%UserAccountSession{
               identity: %Identity{name: %Identity.Name{}, address: %Identity.Address{}},
               identity_edit_history: %IdentityEditHistory{
                 name: %EditCounts{},
                 official_document: %OfficialDocument{ssn: %EditCounts{}}
               },
               items: [%Item{}]
             })
  end

  describe "layer create_session_token/2" do
    @tag :unit
    test "submits request and unmarshalls response", %{config: config} do
      body = http_response_body(:layer_session_token)

      PlaidMock
      |> expect(:send_request, fn request, _client ->
        assert request.method == :post
        assert request.endpoint == "session/token/create"
        assert %{metadata: _} = request.opts
        assert request.body == @session_token_params
        {:ok, %Tesla.Env{}}
      end)
      |> expect(:handle_response, fn _response, mapper ->
        {:ok, mapper.(body)}
      end)

      expected = %SessionToken{
        link: %SessionToken.Link{
          link_token: body["link"]["link_token"],
          expiration: body["link"]["expiration"],
          user_id: body["link"]["user_id"]
        },
        request_id: body["request_id"]
      }

      assert {:ok, ^expected} = Plaid.Layer.create_session_token(@session_token_params, config)
    end

    @tag :integration
    test "success integration test" do
      bypass = Bypass.open()
      config = bypass_config(bypass)
      body = http_response_body(:layer_session_token)

      Bypass.expect(bypass, "POST", "/session/token/create", fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(200, JSON.encode!(body))
      end)

      assert {:ok, %SessionToken{link: %SessionToken.Link{link_token: "link-sandbox-" <> _}}} =
               Plaid.Layer.create_session_token(@session_token_params, config)
    end

    @tag :integration
    test "error integration test" do
      bypass = Bypass.open()
      config = bypass_config(bypass)
      body = http_response_body(:error)

      Bypass.expect(bypass, fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(400, JSON.encode!(body))
      end)

      assert {:error, %Plaid.Error{}} =
               Plaid.Layer.create_session_token(@session_token_params, config)
    end
  end

  describe "layer get_user_account_session/2" do
    @tag :unit
    test "submits request and unmarshalls response", %{config: config} do
      body = http_response_body(:layer_user_account_session)

      PlaidMock
      |> expect(:send_request, fn request, _client ->
        assert request.method == :post
        assert request.endpoint == "user_account/session/get"
        assert %{metadata: _} = request.opts
        assert request.body == @user_account_session_params
        {:ok, %Tesla.Env{}}
      end)
      |> expect(:handle_response, fn _response, mapper ->
        {:ok, mapper.(body)}
      end)

      identity = body["identity"]
      counts = body["identity_edit_history"]["name"]

      edit_counts = %EditCounts{
        edits_current: counts["edits_current"],
        edits_1d: counts["edits_1d"],
        edits_30d: counts["edits_30d"],
        edits_365d: counts["edits_365d"],
        edits_all_time: counts["edits_all_time"]
      }

      expected = %UserAccountSession{
        identity: %Identity{
          name: %Identity.Name{
            first_name: identity["name"]["first_name"],
            last_name: identity["name"]["last_name"]
          },
          address: %Identity.Address{
            street: identity["address"]["street"],
            street2: identity["address"]["street2"],
            city: identity["address"]["city"],
            region: identity["address"]["region"],
            postal_code: identity["address"]["postal_code"],
            country: identity["address"]["country"]
          },
          email: identity["email"],
          phone_number: identity["phone_number"],
          date_of_birth: identity["date_of_birth"],
          ssn: identity["ssn"],
          ssn_last_4: identity["ssn_last_4"]
        },
        identity_edit_history: %IdentityEditHistory{
          name: edit_counts,
          address: edit_counts,
          email: edit_counts,
          date_of_birth: edit_counts,
          official_document: %OfficialDocument{ssn: edit_counts}
        },
        items:
          Enum.map(body["items"], fn item ->
            %Item{item_id: item["item_id"], access_token: item["access_token"]}
          end),
        link_session_id: body["link_session_id"],
        idv_session_status: body["idv_session_status"],
        request_id: body["request_id"]
      }

      assert {:ok, ^expected} =
               Plaid.Layer.get_user_account_session(@user_account_session_params, config)
    end

    @tag :unit
    test "keeps nil for omitted and null optional fields", %{config: config} do
      body =
        :layer_user_account_session
        |> http_response_body()
        |> Map.drop(["identity_edit_history", "idv_session_status"])
        |> Map.put("link_session_id", nil)
        |> Map.put("identity", nil)

      PlaidMock
      |> expect(:send_request, fn _request, _client -> {:ok, %Tesla.Env{}} end)
      |> expect(:handle_response, fn _response, mapper -> {:ok, mapper.(body)} end)

      assert {:ok,
              %UserAccountSession{
                identity: nil,
                identity_edit_history: nil,
                idv_session_status: nil,
                link_session_id: nil,
                items: [%Item{}]
              }} = Plaid.Layer.get_user_account_session(@user_account_session_params, config)
    end

    @tag :integration
    test "success integration test" do
      bypass = Bypass.open()
      config = bypass_config(bypass)
      body = http_response_body(:layer_user_account_session)

      Bypass.expect(bypass, "POST", "/user_account/session/get", fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(200, JSON.encode!(body))
      end)

      assert {:ok, %UserAccountSession{identity: %Identity{name: %Identity.Name{}}}} =
               Plaid.Layer.get_user_account_session(@user_account_session_params, config)
    end

    @tag :integration
    test "error integration test" do
      bypass = Bypass.open()
      config = bypass_config(bypass)
      body = http_response_body(:error)

      Bypass.expect(bypass, fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(400, JSON.encode!(body))
      end)

      assert {:error, %Plaid.Error{}} =
               Plaid.Layer.get_user_account_session(@user_account_session_params, config)
    end
  end

  test "keeps distinct per-field edit counts, partial history and an empty Item list", %{
    config: config
  } do
    body =
      :layer_user_account_session
      |> http_response_body()
      |> Map.put("items", [])
      |> Map.put("identity_edit_history", %{
        "name" => %{"edits_current" => 0, "edits_30d" => 2},
        "email" => %{"edits_current" => 3, "edits_30d" => 4},
        "official_document" => %{"ssn" => %{"edits_current" => 5, "edits_30d" => 6}}
      })

    PlaidMock
    |> expect(:send_request, fn _request, _client -> {:ok, %Tesla.Env{}} end)
    |> expect(:handle_response, fn _response, mapper -> {:ok, mapper.(body)} end)

    assert {:ok, %UserAccountSession{items: [], identity_edit_history: history}} =
             Plaid.Layer.get_user_account_session(@user_account_session_params, config)

    assert %EditCounts{edits_current: 0, edits_30d: 2, edits_1d: nil} = history.name
    assert %EditCounts{edits_current: 3, edits_30d: 4} = history.email

    assert %OfficialDocument{ssn: %EditCounts{edits_current: 5, edits_30d: 6}} =
             history.official_document

    assert history.address == nil
    assert history.date_of_birth == nil
  end

  defp bypass_config(bypass) do
    %{
      client_id: "test_id",
      secret: "test_secret",
      root_uri: "http://localhost:#{bypass.port}/"
    }
  end
end
