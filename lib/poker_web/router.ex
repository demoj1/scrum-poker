defmodule PokerWeb.Router do
  use PokerWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {PokerWeb.LayoutView, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", PokerWeb do
    pipe_through :browser

    live "/ws/:room", RoomLive, :index, session: %{"user_id" => nil}
    live "/ws", PageLive, :index, session: %{"user_id" => nil}
    get "/logout", Controller.Login, :logout
    get "/", Controller.Login, :index
    post "/", Controller.Login, :auth
  end
end
