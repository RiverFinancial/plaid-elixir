# Changelog

## Unreleased (River fork)

- Non-2xx responses whose body is not a JSON object (proxy 502 HTML, Envoy
  plaintext) return `{:error, %Plaid.Error{http_code: status, error_message: body}}`
  instead of raising `BadMapError`. The message is capped at 1,000 bytes, invalid
  UTF-8 is replaced, and non-string bodies are inspected. A body sent as
  `application/json` that fails to decode still returns Tesla's decode error.
- Replace Poison response mapping with an internal mapper that preserves nested
  structs, missing/null fields, schema defaults, and unknown-field handling.
- Use native `JSON` for HTTP encoding/decoding; retain Jason support for response
  struct serialization. Native codec errors replace Jason-specific errors for
  malformed JSON and unsupported request values (see the README).
- Require Elixir 1.18+, Erlang/OTP 27+, and Tesla 1.14+.
- Make hackney an optional dependency and use Erlang's built-in httpc
  (`Tesla.Adapter.Httpc`) as the default adapter. httpc verifies certificates
  by default on OTP 27+. With httpc, `timeout` defaults to 30 seconds and can
  be changed through `http_options`. httpc ignores hackney options such as
  `recv_timeout`, so apps that relied on hackney options should switch to
  httpc's `timeout` and `connect_timeout`, or add `:hackney` to their own
  dependencies and set `adapter: Tesla.Adapter.Hackney`.
- Align the standalone Tesla/Hackney lock versions with Alto and refresh their
  required transitive dependencies. Update the Cowboy/Cowlib test dependencies
  for OTP 29 compatibility. Alto's HTTP dependency versions are unchanged.
- Replace the old Travis configuration with GitHub CI on Elixir 1.18/OTP 27 and
  Elixir 1.20/OTP 29. Serialize the existing global-state/telemetry tests.

## v3.0

### Hard Deprecations
- `Plaid.get_cred/0` - Soft deprecated since `2.0`
- `Plaid.get_key/0` - Soft deprecated since `2.0`
- `Plaid.make_request/5` - Soft deprecated since `2.0`
- `Plaid.make_request_with_cred/6` - Replaced by `Plaid.send_request/2`
- `Plaid.Utils` - Removed and moved unmarshalling into calling module
- `Plaid.Item.create_processor_token/3` - Replaced by `Plaid.Item.create_processor_token/2`
- `Plaid.Telemetry` - No longer called by default. Must be added to `config`

### Return Type Changes
- `Plaid.PaymentInitiation.Payments.create/2` - Returns `Plaid.PaymentInitiation.Payments.Payment.t` instead of `Plaid.PaymentInitiation.Payments.t`
- `Plaid.PaymentInitiation.Payments.list/2` - Returns `Plaid.PaymentInitiation.Payments.t` instead of `[Plaid.PaymentInitiation.Payments.Payment.t]`. Access the former's `payments` key instead
- `Plaid.PaymentInitiation.Recipients.create/2` - Returns `Plaid.PaymentInitiation.Recipients.Recipient.t` instead of `Plaid.PaymentInitiation.Recipients.t`
- `Plaid.PaymentInitiation.Recipients.list/1` - Returns `Plaid.PaymentInitiation.Recipients.t` instead of `[Plaid.PaymentInitiation.Recipients.Recipient.t]` Access the former's `recipients` key instead

### Struct Changes
- `Plaid.Auth` - Fixed bug causing the `numbers` key not to be set to type `Plaid.Auth.Numbers`
- `Plaid.PaymentInitiation.Payments` - Modified to remove `payment_id` and include `payments` and `next_cursor` to match library pattern for arrays returned by Plaid. Access `payment_id` in `Plaid.PaymentInitiation.Payments.Payment` instead
- `Plaid.PaymentInitiation.Payments.Payment.amount` - Changed default value to `nil` from `0`
- `Plaid.PaymentInitiation.Recipients` - Modified to remove `recipient_id` and include `recipients` to match library pattern for arrays returned by Plaid. Access `recipient_id` in `Plaid.PaymentInitiation.Recipients.Recipient` instead
- `Plaid.PaymentInitiation.Payments` - Fixed bug causing the `amount` and `schedule` keys not to be set to their respective struct types
- `Plaid.PaymentInitiation.Recipients` - Fixed bug causing the `address` key not to be set to type `Plaid.PaymentInitiation.Recipients.Recipient.Address`

### Type Changes
- `Plaid.Item` - Removed type `service` which is now passed in the `params` argument to `Plaid.Item.create_processor_token/2`

### Configuration
- Added `adapter` to support Tesla
- Added `middleware` to support Tesla
- `httpoison_options` changed to `http_options`

### Project Structure
- Moved HTTP request functionality to `Tesla` for better testing and customization
- Replaced all telemetry functionality with `Tesla.Middleware.Telemetry`
