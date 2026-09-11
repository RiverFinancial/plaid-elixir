defmodule Plaid.ResponseMapperTest do
  use ExUnit.Case, async: true

  alias Plaid.Accounts
  alias Plaid.Accounts.Account
  alias Plaid.Accounts.Account.Balance
  alias Plaid.Accounts.Account.Owner
  alias Plaid.Auth
  alias Plaid.ResponseMapper

  describe "transform/2" do
    test "maps nested structs and lists without changing scalar values" do
      body = %{
        "accounts" => [
          %{
            "account_id" => "account-1",
            "balances" => %{"available" => 10.25, "current" => 12, "limit" => nil},
            "owners" => [
              %{
                "names" => ["Example Owner"],
                "emails" => [%{"data" => "owner@example.com", "primary" => false}]
              }
            ]
          }
        ],
        "item" => %{"item_id" => "item-1"},
        "request_id" => "request-1"
      }

      template = %Accounts{
        accounts: [%Account{balances: %Balance{}, owners: [%Owner{emails: [%Owner.Email{}]}]}],
        item: %Plaid.Item{}
      }

      assert ResponseMapper.transform(body, template) == %Accounts{
               accounts: [
                 %Account{
                   account_id: "account-1",
                   balances: %Balance{available: 10.25, current: 12, limit: nil},
                   owners: [
                     %Owner{
                       names: ["Example Owner"],
                       emails: [%Owner.Email{data: "owner@example.com", primary: false}]
                     }
                   ]
                 }
               ],
               item: %Plaid.Item{item_id: "item-1"},
               request_id: "request-1"
             }
    end

    test "missing nested fields use schema defaults instead of template structs" do
      template = %Accounts{
        accounts: [%Account{balances: %Balance{}, owners: [%Owner{}]}],
        item: %Plaid.Item{}
      }

      assert ResponseMapper.transform(%{}, template) == %Accounts{}

      assert ResponseMapper.transform(%{"accounts" => [%{"account_id" => "account-1"}]}, template) ==
               %Accounts{accounts: [%Account{account_id: "account-1"}]}
    end

    test "explicit null stays null and empty lists stay empty" do
      template = %Accounts{accounts: [%Account{balances: %Balance{}}], item: %Plaid.Item{}}

      assert ResponseMapper.transform(%{"accounts" => nil, "item" => nil}, template) ==
               %Accounts{accounts: nil}

      assert ResponseMapper.transform(%{"accounts" => [], "item" => nil}, template) ==
               %Accounts{accounts: []}

      assert ResponseMapper.transform(%{"accounts" => [nil, %{"balances" => nil}]}, template) ==
               %Accounts{accounts: [nil, %Account{}]}
    end

    test "empty objects become structs without populating absent nested fields" do
      template = %Accounts{accounts: [%Account{balances: %Balance{}, owners: [%Owner{}]}]}

      assert ResponseMapper.transform(%{"accounts" => [%{"balances" => %{}}]}, template) ==
               %Accounts{accounts: [%Account{balances: %Balance{}}]}
    end

    test "only declared string keys populate fields" do
      body = %{
        "item_id" => "item-1",
        "unrecognized_field" => %{"nested" => 1},
        "__struct__" => "not-a-module",
        :request_id => "not-a-json-key"
      }

      assert ResponseMapper.transform(body, %Plaid.Item{}) == %Plaid.Item{item_id: "item-1"}
    end

    test "untyped objects and arrays retain their string keys and values" do
      body = %{
        "error" => %{"error_code" => "ITEM_LOGIN_REQUIRED", "details" => [%{"attempt" => 1}]},
        "available_products" => ["auth", "transactions"]
      }

      assert ResponseMapper.transform(body, %Plaid.Item{}) == %Plaid.Item{
               error: %{
                 "error_code" => "ITEM_LOGIN_REQUIRED",
                 "details" => [%{"attempt" => 1}]
               },
               available_products: ["auth", "transactions"]
             }
    end

    test "missing scalar fields retain template defaults but null overrides them" do
      template = %Plaid.Error{http_code: 400, error_message: "default"}

      assert ResponseMapper.transform(%{}, template) ==
               %Plaid.Error{http_code: 400, error_message: "default"}

      assert ResponseMapper.transform(%{"http_code" => nil, "error_message" => nil}, template) ==
               %Plaid.Error{}
    end

    test "preserves tokenized ACH account flags" do
      template = %Auth{numbers: %Auth.Numbers{ach: [%Auth.Numbers.ACH{}]}}

      body = %{
        "numbers" => %{
          "ach" => [
            %{"account_id" => "tokenized", "is_tokenized_account_number" => true},
            %{"account_id" => "plain", "is_tokenized_account_number" => false},
            %{"account_id" => "unspecified"}
          ]
        }
      }

      assert ResponseMapper.transform(body, template) == %Auth{
               numbers: %Auth.Numbers{
                 ach: [
                   %Auth.Numbers.ACH{account_id: "tokenized", is_tokenized_account_number: true},
                   %Auth.Numbers.ACH{account_id: "plain", is_tokenized_account_number: false},
                   %Auth.Numbers.ACH{account_id: "unspecified"}
                 ]
               }
             }
    end

    test "preserves scalar responses and scalar values in nested fields" do
      assert ResponseMapper.transform(nil, %Accounts{}) == nil
      assert ResponseMapper.transform("unparsed", %Accounts{}) == "unparsed"
      assert ResponseMapper.transform(false, %Accounts{}) == false

      assert ResponseMapper.transform(%{"item" => "unexpected"}, %Accounts{item: %Plaid.Item{}}) ==
               %Accounts{item: "unexpected"}
    end

    test "maps top-level lists and leaves empty lists empty" do
      assert ResponseMapper.transform([%{"item_id" => "item-1"}, nil], [%Plaid.Item{}]) ==
               [%Plaid.Item{item_id: "item-1"}, nil]

      assert ResponseMapper.transform([], [%Plaid.Item{}]) == []
    end

    test "retains schema defaults when a nested value equals the template" do
      template = %Accounts{accounts: [%Account{}], item: %Plaid.Item{}}

      assert ResponseMapper.transform(
               %{"accounts" => [%Account{}], "item" => %Plaid.Item{}},
               template
             ) == %Accounts{}
    end
  end

  test "API errors retain their fields and the HTTP response status" do
    response = %Tesla.Env{
      status: 429,
      body: %{
        "error_type" => "RATE_LIMIT_EXCEEDED",
        "error_code" => "ACCOUNTS_LIMIT",
        "error_message" => "Too many requests",
        "display_message" => nil,
        "request_id" => "request-1",
        "http_code" => 400,
        "unknown" => "ignored"
      }
    }

    assert Plaid.handle_response({:ok, response}, & &1) ==
             {:error,
              %Plaid.Error{
                error_type: "RATE_LIMIT_EXCEEDED",
                error_code: "ACCOUNTS_LIMIT",
                error_message: "Too many requests",
                display_message: nil,
                request_id: "request-1",
                http_code: 429
              }}
  end

  test "transport errors pass through without response mapping" do
    assert Plaid.handle_response({:error, :timeout}, & &1) == {:error, :timeout}
  end
end
