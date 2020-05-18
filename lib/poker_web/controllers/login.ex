defmodule PokerWeb.Controller.Login do
  use PokerWeb, :controller
  use Phoenix.Controller
  import Phoenix.LiveView.Controller

  plug Plug.Session,
    store: :cookie,
    key: "_poker",
    encryption_salt: "oPElUX9FoEVJkyddZwsBeCwApI9BYB7RmzH8et4m1MKOhEZ9uHGZsrq1hYIpwn9h",
    signing_salt: "oPElUX9FoEVJkyddZwsBeCwApI9BYB7RmzH8et4m1MKOhEZ9uHGZsrq1hYIpwn9ht",
    key_length: 64,
    log: :debug

  def index(conn, params) do
    user = get_session(conn, :user)

    if user == nil do
      render(conn, "login.html", %{room: params["room"]})
    else
      conn
      |> redirect(to: "/ws")
      |> live_render(PokerWeb.PageLive)
    end
  end

  def logout(conn, _params) do
    conn
    |> clear_session()
    |> redirect(to: "/")
  end

  def auth(conn, params) do
    conn =
      conn
      |> put_session(:user, %{name: params["name"], id: System.unique_integer()})
      |> put_status(302)

    case params["room"] do
      nil ->
        conn
        |> redirect(to: "/ws")
        |> live_render(PokerWeb.PageLive)
      room ->
        conn
        |> redirect(to: "/ws/#{room}")
        |> live_render(PokerWeb.RoomLive)
    end
  end
end
