defmodule Plaid.Response do
  @moduledoc """
  The decoded HTTP body and the endpoint result, returned when
  `response_mode: :full` is passed in the endpoint configuration.

  `result` has the endpoint's usual `{:ok, value}` or `{:error, reason}` shape.
  `body` and `status` are `nil` when no HTTP response was received. The body
  contains sensitive data and must be redacted before persistence or logging.
  """

  defstruct [:result, :body, :status]

  @type t :: %__MODULE__{
          result: {:ok, term()} | {:error, term()},
          body: term(),
          status: non_neg_integer() | nil
        }
end
