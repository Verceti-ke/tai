defmodule Tai.Commands.MarketsTest do
  use ExUnit.Case, async: false
  import ExUnit.CaptureIO
  alias Tai.Markets.{Quote, PricePoint}

  setup do
    start_supervised!({Tai.PubSub, 1})
    start_supervised!(Tai.Markets.QuoteStore)
    :ok
  end

  test "shows all inside quotes and the time they were last processed and changed" do
    %Quote{
      venue_id: :test_exchange_a,
      product_symbol: :btc_usd,
      bids: [%PricePoint{price: 12_999.99, size: 0.000021}],
      asks: [%PricePoint{price: 13_000.01, size: 1.11}]
    }
    |> Tai.Markets.QuoteStore.upsert()

    %Quote{
      venue_id: :test_exchange_a,
      product_symbol: :ltc_usd,
      bids: [%PricePoint{price: 101.99, size: 1.3}]
    }
    |> Tai.Markets.QuoteStore.upsert()

    %Quote{
      venue_id: :test_exchange_a,
      product_symbol: :eth_usd,
      asks: [%PricePoint{price: 195.66, size: 0.12}]
    }
    |> Tai.Markets.QuoteStore.upsert()

    assert capture_io(&Tai.CommandsHelper.markets/0) == """
           +-----------------+---------+-----------+-----------+----------+----------+
           |           Venue | Product | Bid Price | Ask Price | Bid Size | Ask Size |
           +-----------------+---------+-----------+-----------+----------+----------+
           | test_exchange_a | btc_usd |  12999.99 |  13000.01 | 0.000021 |     1.11 |
           | test_exchange_a | eth_usd |         ~ |    195.66 |        ~ |     0.12 |
           | test_exchange_a | ltc_usd |    101.99 |         ~ |      1.3 |        ~ |
           +-----------------+---------+-----------+-----------+----------+----------+\n
           """
  end
end
