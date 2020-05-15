defmodule Poker.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      {Phoenix.PubSub, name: Poker.PubSub},
      PokerWeb.Endpoint,
      Poker.Coordinator
    ]

    opts = [strategy: :one_for_one, name: Poker.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def config_change(changed, _new, removed) do
    PokerWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
