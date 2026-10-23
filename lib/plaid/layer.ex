defmodule Plaid.Layer do
  @moduledoc """
  Functions for Plaid `Layer` endpoints.
  """

  alias Plaid.Client.Request
  alias Plaid.Client

  @type params :: %{required(atom) => term}
  @type config :: %{required(atom) => String.t() | keyword}
  @type error :: {:error, Plaid.Error.t() | any()} | no_return

  defmodule SessionToken do
    @moduledoc """
    Plaid Layer session token data structure.
    """

    @derive Jason.Encoder
    defstruct link: nil,
              request_id: nil

    @type t :: %__MODULE__{
            link: Plaid.Layer.SessionToken.Link.t(),
            request_id: String.t()
          }

    defmodule Link do
      @moduledoc """
      Plaid Layer session token Link data structure.
      """

      @derive Jason.Encoder
      defstruct link_token: nil,
                expiration: nil,
                user_id: nil

      @type t :: %__MODULE__{
              link_token: String.t(),
              expiration: String.t(),
              user_id: String.t() | nil
            }
    end
  end

  defmodule UserAccountSession do
    @moduledoc """
    Plaid Layer user account session data structure.
    """

    @derive Jason.Encoder
    defstruct identity: nil,
              identity_edit_history: nil,
              items: nil,
              link_session_id: nil,
              idv_session_status: nil,
              request_id: nil

    @type t :: %__MODULE__{
            identity: Plaid.Layer.UserAccountSession.Identity.t() | nil,
            identity_edit_history: Plaid.Layer.UserAccountSession.IdentityEditHistory.t() | nil,
            items: [Plaid.Layer.UserAccountSession.Item.t()],
            link_session_id: String.t() | nil,
            idv_session_status: String.t() | nil,
            request_id: String.t()
          }

    defmodule Identity do
      @moduledoc """
      Plaid Layer user account identity data structure.
      """

      @derive Jason.Encoder
      defstruct name: nil,
                address: nil,
                email: nil,
                phone_number: nil,
                date_of_birth: nil,
                ssn: nil,
                ssn_last_4: nil

      @type t :: %__MODULE__{
              name: Plaid.Layer.UserAccountSession.Identity.Name.t() | nil,
              address: Plaid.Layer.UserAccountSession.Identity.Address.t() | nil,
              email: String.t() | nil,
              phone_number: String.t() | nil,
              date_of_birth: String.t() | nil,
              ssn: String.t() | nil,
              ssn_last_4: String.t() | nil
            }

      defmodule Name do
        @moduledoc """
        Plaid Layer user account identity name data structure.
        """

        @derive Jason.Encoder
        defstruct first_name: nil,
                  last_name: nil

        @type t :: %__MODULE__{
                first_name: String.t(),
                last_name: String.t()
              }
      end

      defmodule Address do
        @moduledoc """
        Plaid Layer user account identity address data structure.
        """

        @derive Jason.Encoder
        defstruct street: nil,
                  street2: nil,
                  city: nil,
                  region: nil,
                  postal_code: nil,
                  country: nil

        @type t :: %__MODULE__{
                street: String.t() | nil,
                street2: String.t() | nil,
                city: String.t() | nil,
                region: String.t() | nil,
                postal_code: String.t() | nil,
                country: String.t() | nil
              }
      end
    end

    defmodule IdentityEditHistory do
      @moduledoc """
      Plaid Layer user account identity edit history data structure.
      """

      @derive Jason.Encoder
      defstruct name: nil,
                address: nil,
                email: nil,
                date_of_birth: nil,
                official_document: nil

      @type t :: %__MODULE__{
              name: Plaid.Layer.UserAccountSession.IdentityEditHistory.EditCounts.t(),
              address: Plaid.Layer.UserAccountSession.IdentityEditHistory.EditCounts.t(),
              email: Plaid.Layer.UserAccountSession.IdentityEditHistory.EditCounts.t(),
              date_of_birth: Plaid.Layer.UserAccountSession.IdentityEditHistory.EditCounts.t(),
              official_document:
                Plaid.Layer.UserAccountSession.IdentityEditHistory.OfficialDocument.t() | nil
            }

      defmodule EditCounts do
        @moduledoc """
        Plaid Layer identity edit counts data structure.
        """

        @derive Jason.Encoder
        defstruct edits_current: nil,
                  edits_1d: nil,
                  edits_30d: nil,
                  edits_365d: nil,
                  edits_all_time: nil

        @type t :: %__MODULE__{
                edits_current: integer(),
                edits_1d: integer(),
                edits_30d: integer(),
                edits_365d: integer(),
                edits_all_time: integer()
              }
      end

      defmodule OfficialDocument do
        @moduledoc """
        Plaid Layer official document edit history data structure.
        """

        @derive Jason.Encoder
        defstruct ssn: nil

        @type t :: %__MODULE__{
                ssn: Plaid.Layer.UserAccountSession.IdentityEditHistory.EditCounts.t()
              }
      end
    end

    defmodule Item do
      @moduledoc """
      Plaid Layer user account Item data structure.
      """

      @derive Jason.Encoder
      defstruct item_id: nil,
                access_token: nil

      @type t :: %__MODULE__{
              item_id: String.t(),
              access_token: String.t()
            }
    end
  end

  @doc """
  Creates a Layer session token.

  Parameters
  ```
  %{
    template_id: "template_4uinBNe4B2x9",
    user: %{client_user_id: "user-abc"},
    redirect_uri: "https://example.com/oauth"
  }
  ```
  """
  @spec create_session_token(params, config) :: {:ok, Plaid.Layer.SessionToken.t()} | error
  def create_session_token(params, config \\ %{}) do
    request_operation("session/token/create", params, config, &map_session_token/1)
  end

  @doc """
  Retrieves the user account data for a completed Layer session.

  Parameters
  ```
  %{
    public_token: "public-sandbox-a1b2c3d4-e5f6-7890-abcd-ef1234567890"
  }
  ```
  """
  @spec get_user_account_session(params, config) ::
          {:ok, Plaid.Layer.UserAccountSession.t()} | error
  def get_user_account_session(params, config \\ %{}) do
    request_operation("user_account/session/get", params, config, &map_user_account_session/1)
  end

  defp map_session_token(body) do
    Plaid.ResponseMapper.transform(
      body,
      %Plaid.Layer.SessionToken{link: %Plaid.Layer.SessionToken.Link{}}
    )
  end

  defp map_user_account_session(body) do
    edit_counts = %Plaid.Layer.UserAccountSession.IdentityEditHistory.EditCounts{}

    Plaid.ResponseMapper.transform(
      body,
      %Plaid.Layer.UserAccountSession{
        identity: %Plaid.Layer.UserAccountSession.Identity{
          name: %Plaid.Layer.UserAccountSession.Identity.Name{},
          address: %Plaid.Layer.UserAccountSession.Identity.Address{}
        },
        identity_edit_history: %Plaid.Layer.UserAccountSession.IdentityEditHistory{
          name: edit_counts,
          address: edit_counts,
          email: edit_counts,
          date_of_birth: edit_counts,
          official_document: %Plaid.Layer.UserAccountSession.IdentityEditHistory.OfficialDocument{
            ssn: edit_counts
          }
        },
        items: [%Plaid.Layer.UserAccountSession.Item{}]
      }
    )
  end

  defp request_operation(endpoint, params, config, mapper) do
    c = config[:client] || Plaid

    Request
    |> struct(method: :post, endpoint: endpoint, body: params)
    |> Request.add_metadata(config)
    |> c.send_request(Client.new(config))
    |> c.handle_response(mapper)
  end
end
