defmodule Plaid.PaymentInitiation.Recipients do
  @moduledoc """
  Functions for Plaid `payment_initiation/recipient` endpoints.
  """

  alias Plaid.Client.Request

  @derive Jason.Encoder
  defstruct recipients: [], request_id: nil

  @type t :: %__MODULE__{
          recipients: [Plaid.PaymentInitiation.Recipients.Recipient.t()],
          request_id: String.t()
        }
  @type params :: %{required(atom) => term}
  @type config :: %{required(atom) => String.t() | keyword}
  @type error :: {:error, Plaid.Error.t() | any()} | no_return

  defmodule Recipient do
    @moduledoc """
    Plaid Recipient data structure.
    """

    @derive Jason.Encoder
    defstruct recipient_id: nil,
              name: nil,
              iban: nil,
              address: nil,
              request_id: nil

    @type t :: %__MODULE__{
            recipient_id: String.t(),
            name: String.t(),
            iban: String.t(),
            address: Plaid.PaymentInitiation.Recipients.Recipient.Address.t(),
            request_id: String.t()
          }

    defmodule Address do
      @moduledoc """
      Plaid Recipient Address data structure.
      """

      @derive Jason.Encoder
      defstruct street: nil,
                city: nil,
                postal_code: nil,
                country: nil

      @type t :: %__MODULE__{
              street: [String.t()],
              city: String.t(),
              postal_code: String.t(),
              country: String.t()
            }
    end
  end

  @doc """
  Creates recipient.

  Parameters
  ```
  %{

  }
  ```
  """
  @spec create(params, config) ::
          {:ok, Plaid.PaymentInitiation.Recipients.Recipient.t()} | error | Plaid.Response.t()
  def create(params, config \\ %{}) do
    request_operation("payment_initiation/recipient/create", params, config, &map_recipient(&1))
  end

  defp request_operation(endpoint, params, config, mapper) do
    Request
    |> struct(method: :post, endpoint: endpoint, body: params)
    |> Plaid.request(config, mapper)
  end

  defp map_recipients(body) do
    Plaid.ResponseMapper.transform(body, %Plaid.PaymentInitiation.Recipients{
      recipients: [full_struct()]
    })
  end

  defp map_recipient(body) do
    Plaid.ResponseMapper.transform(body, full_struct())
  end

  defp full_struct do
    %Plaid.PaymentInitiation.Recipients.Recipient{
      address: %Plaid.PaymentInitiation.Recipients.Recipient.Address{}
    }
  end

  @doc """
  Gets recipient by recipient_id.

  Parameters
  ```
  %{
    recipient_id: ""
  }
  ```
  """
  @spec get(params, config) ::
          {:ok, Plaid.PaymentInitiation.Recipients.Recipient.t()} | error | Plaid.Response.t()
  def get(params, config \\ %{}) do
    request_operation("payment_initiation/recipient/get", params, config, &map_recipient(&1))
  end

  @doc """
  Lists all recipients.
  """
  @spec list(config) :: {:ok, Plaid.PaymentInitiation.Recipients.t()} | error | Plaid.Response.t()
  def list(config \\ %{}) do
    request_operation("payment_initiation/recipient/list", %{}, config, &map_recipients(&1))
  end
end
