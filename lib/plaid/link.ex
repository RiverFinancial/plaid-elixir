defmodule Plaid.Link do
  @moduledoc """
  Functions for Plaid `link` endpoint.
  """

  alias Plaid.Client.Request

  @derive Jason.Encoder
  defstruct link_token: nil,
            expiration: nil,
            # Deprecated, not returned by Plaid.
            request_id: nil,
            created_at: nil,
            metadata: nil,
            link_sessions: nil

  @type t :: %__MODULE__{
          link_token: String.t(),
          expiration: String.t(),
          request_id: String.t(),
          created_at: String.t(),
          metadata: Plaid.Link.Metadata.t(),
          link_sessions: [Plaid.Link.Session.t()] | nil
        }
  @type params :: %{required(atom) => term}
  @type config :: %{required(atom) => String.t() | keyword}
  @type error :: {:error, Plaid.Error.t() | any()} | no_return

  defmodule Metadata do
    @moduledoc """
    Plaid Link Metadata data structure.
    """

    @derive Jason.Encoder
    defstruct initial_products: nil,
              webhook: nil,
              country_codes: nil,
              language: nil,
              account_filters: nil,
              redirect_uri: nil,
              products: nil,
              client_name: nil,
              user: nil,
              access_token: nil

    @type t :: %__MODULE__{
            initial_products: [String.t()],
            products: [String.t()],
            webhook: String.t(),
            country_codes: [String.t()],
            language: String.t(),
            account_filters: map(),
            redirect_uri: String.t(),
            client_name: String.t(),
            user: map(),
            access_token: String.t()
          }
  end

  defmodule Session do
    @moduledoc """
    Plaid Link session data structure, returned in `link_sessions` by
    `/link/token/get`.

    `on_success` and `on_exit` are deprecated by Plaid and kept as raw maps.
    """

    @derive Jason.Encoder
    defstruct link_session_id: nil,
              started_at: nil,
              finished_at: nil,
              on_success: nil,
              on_exit: nil,
              exit: nil,
              events: nil,
              results: nil

    @type t :: %__MODULE__{
            link_session_id: String.t(),
            started_at: String.t() | nil,
            finished_at: String.t() | nil,
            on_success: map() | nil,
            on_exit: map() | nil,
            exit: Plaid.Link.Session.Exit.t() | nil,
            events: [Plaid.Link.Session.Event.t()] | nil,
            results: Plaid.Link.Session.Results.t() | nil
          }

    defmodule Exit do
      @moduledoc """
      Plaid Link session exit data structure.
      """

      @derive Jason.Encoder
      defstruct error: nil,
                metadata: nil

      @type t :: %__MODULE__{
              error: map() | nil,
              metadata: map() | nil
            }
    end

    defmodule Event do
      @moduledoc """
      Plaid Link session event data structure.
      """

      @derive Jason.Encoder
      defstruct event_name: nil,
                timestamp: nil,
                event_id: nil,
                event_metadata: nil

      @type t :: %__MODULE__{
              event_name: String.t(),
              timestamp: String.t(),
              event_id: String.t(),
              event_metadata: Plaid.Link.Session.Event.Metadata.t()
            }

      defmodule Metadata do
        @moduledoc """
        Plaid Link session event metadata data structure.
        """

        @derive Jason.Encoder
        defstruct error_code: nil,
                  error_message: nil,
                  error_type: nil,
                  exit_status: nil,
                  institution_id: nil,
                  institution_name: nil,
                  institution_search_query: nil,
                  request_id: nil,
                  mfa_type: nil,
                  view_name: nil,
                  selection: nil,
                  brand_name: nil,
                  match_reason: nil,
                  routing_number: nil,
                  account_number_mask: nil

        @type t :: %__MODULE__{
                error_code: String.t() | nil,
                error_message: String.t() | nil,
                error_type: String.t() | nil,
                exit_status: String.t() | nil,
                institution_id: String.t() | nil,
                institution_name: String.t() | nil,
                institution_search_query: String.t() | nil,
                request_id: String.t() | nil,
                mfa_type: String.t() | nil,
                view_name: String.t() | nil,
                selection: String.t() | nil,
                brand_name: String.t() | nil,
                match_reason: String.t() | nil,
                routing_number: String.t() | nil,
                account_number_mask: String.t() | nil
              }
      end
    end

    defmodule Results do
      @moduledoc """
      Plaid Link session results data structure.

      Only `item_add_results` is mapped to structs; the other result lists are
      kept as raw maps.
      """

      @derive Jason.Encoder
      defstruct item_add_results: nil,
                cra_item_add_results: nil,
                cra_update_results: nil,
                bank_income_results: nil,
                payroll_income_results: nil,
                document_income_results: nil,
                cra_document_upload_results: nil

      @type t :: %__MODULE__{
              item_add_results: [Plaid.Link.Session.ItemAddResult.t()] | nil,
              cra_item_add_results: [map()] | nil,
              cra_update_results: [map()] | nil,
              bank_income_results: [map()] | nil,
              payroll_income_results: [map()] | nil,
              document_income_results: map() | nil,
              cra_document_upload_results: map() | nil
            }
    end

    defmodule ItemAddResult do
      @moduledoc """
      Plaid Link session Item add result data structure.
      """

      @derive Jason.Encoder
      defstruct public_token: nil,
                accounts: nil,
                institution: nil

      @type t :: %__MODULE__{
              public_token: String.t(),
              accounts: [map()],
              institution: map() | nil
            }
    end
  end

  @doc """
  Creates a Link Token.

  Parameters
  ```
  %{
    client_name: "",
    language: "",
    country_codes: "",
    user: %{client_user_id: ""}
  }
  ```
  """
  @spec create_link_token(params, config) :: {:ok, Plaid.Link.t()} | error | Plaid.Response.t()
  def create_link_token(params, config \\ %{}) do
    request_operation("link/token/create", params, config)
  end

  defp request_operation(endpoint, params, config) do
    Request
    |> struct(method: :post, endpoint: endpoint, body: params)
    |> Plaid.request(config, &map_link(&1))
  end

  defp map_link(body) do
    Plaid.ResponseMapper.transform(
      body,
      %Plaid.Link{
        metadata: %Plaid.Link.Metadata{},
        link_sessions: [
          %Plaid.Link.Session{
            exit: %Plaid.Link.Session.Exit{},
            events: [
              %Plaid.Link.Session.Event{
                event_metadata: %Plaid.Link.Session.Event.Metadata{}
              }
            ],
            results: %Plaid.Link.Session.Results{
              item_add_results: [%Plaid.Link.Session.ItemAddResult{}]
            }
          }
        ]
      }
    )
  end

  @doc """
  Gets a Link Token's information.

  Parameters
  ```
  %{
    link_token: ""
  }
  ```
  """
  @spec get_link_token(params, config) :: {:ok, Plaid.Link.t()} | error | Plaid.Response.t()
  def get_link_token(params, config \\ %{}) do
    request_operation("link/token/get", params, config)
  end
end
