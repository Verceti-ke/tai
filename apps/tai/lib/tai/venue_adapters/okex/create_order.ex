defmodule Tai.VenueAdapters.OkEx.CreateOrder do
  @moduledoc """
  Create orders for the OkEx adapter
  """

  alias Tai.VenueAdapters.OkEx.ClientId
  alias Tai.Trading.OrderResponses.CreateAccepted

  @type credentials :: Tai.Venues.Adapter.credentials()
  @type order :: Tai.Trading.Order.t()
  @type response :: CreateAccepted.t()
  @type reason :: :insufficient_balance

  @spec create_order(order, credentials) :: {:ok, response} | {:error, reason}
  def create_order(%Tai.Trading.Order{} = order, credentials) do
    {order, credentials}
    |> send_to_venue()
    |> parse_response()
  end

  def send_to_venue({order, credentials}) do
    venue_config = credentials |> to_venue_config
    params = order |> build_params()
    mod = order |> module_for()
    {mod.create_order(params, venue_config), order}
  end

  defp module_for(%Tai.Trading.Order{product_type: :future}), do: ExOkex.Futures.Private
  defp module_for(%Tai.Trading.Order{product_type: :swap}), do: ExOkex.Swap.Private

  defp build_params(%Tai.Trading.Order{product_type: :future} = order) do
    %{
      instrument_id: order.product_symbol |> to_venue_symbol,
      leverage: 20,
      orders_data: [
        order |> build_order_params()
      ]
    }
  end

  defp build_params(%Tai.Trading.Order{product_type: :swap} = order) do
    %{
      instrument_id: order.product_symbol |> to_venue_symbol,
      leverage: 20,
      order_data: [
        order |> build_order_params()
      ]
    }
  end

  defp build_order_params(order) do
    %{
      client_oid: order.client_id |> ClientId.to_venue(),
      price: order.price |> to_decimal_string,
      size: order.qty |> to_decimal_string,
      type: order |> to_venue_type,
      order_type: order |> to_venue_order_type,
      match_price: 0
    }
  end

  defdelegate to_venue_config(credentials),
    to: Tai.VenueAdapters.OkEx.Credentials,
    as: :from

  defdelegate to_venue_symbol(symbols),
    to: Tai.VenueAdapters.OkEx.Products,
    as: :from_symbol

  defp to_decimal_string(price), do: price |> Decimal.to_string(:normal)

  @open_long 1
  @open_short 2
  @close_long 3
  @close_short 4
  defp to_venue_type(%Tai.Trading.Order{side: :buy, close: true}), do: @close_short
  defp to_venue_type(%Tai.Trading.Order{side: :sell, close: true}), do: @close_long
  defp to_venue_type(%Tai.Trading.Order{side: :buy}), do: @open_long
  defp to_venue_type(%Tai.Trading.Order{side: :sell}), do: @open_short

  defp to_venue_order_type(%Tai.Trading.Order{post_only: true}), do: 1
  defp to_venue_order_type(_), do: 0

  defp parse_response({
         {:ok, %{"order_info" => [%{"error_code" => "35008", "error_message" => _} | _]}},
         %Tai.Trading.Order{product_type: :swap}
       }),
       do: {:error, :insufficient_balance}

  defp parse_response({
         {:ok, %{"order_info" => [%{"error_code" => "35010", "error_message" => _} | _]}},
         %Tai.Trading.Order{product_type: :swap}
       }),
       do: {:error, :insufficient_position}

  defp parse_response({
         {:ok, %{"order_info" => [%{"error_code" => "32015", "error_message" => _} | _]}},
         %Tai.Trading.Order{product_type: :future}
       }),
       do: {:error, :insufficient_balance}

  defp parse_response({
         {:ok, %{"order_info" => [%{"error_code" => "32019", "error_message" => _} | _]}},
         %Tai.Trading.Order{product_type: :future}
       }),
       do: {:error, :insufficient_position}

  @invalid_venue_order_id "-1"
  defp parse_response({
         {:ok, %{"order_info" => [%{"order_id" => venue_order_id} | _]}},
         _
       })
       when venue_order_id != @invalid_venue_order_id do
    response = %CreateAccepted{id: venue_order_id, received_at: Timex.now()}
    {:ok, response}
  end
end
