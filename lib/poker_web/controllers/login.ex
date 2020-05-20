defmodule PokerWeb.Controller.Login do
  use PokerWeb, :controller
  use Phoenix.Controller
  import Phoenix.LiveView.Controller
  import Phoenix.Controller

  plug Plug.Session,
    store: :cookie,
    key: "_poker",
    encryption_salt: "oPElUX9FoEVJkyddZwsBeCwApI9BYB7RmzH8et4m1MKOhEZ9uHGZsrq1hYIpwn9h",
    signing_salt: "oPElUX9FoEVJkyddZwsBeCwApI9BYB7RmzH8et4m1MKOhEZ9uHGZsrq1hYIpwn9ht",
    key_length: 64,
    log: :debug

  def index(conn, params) do
    user = get_session(conn, :user)
    ln = params["ln"] || "en"
    Gettext.put_locale(PokerWeb.Gettext, ln)

    if user == nil do
      render(conn, "login.html", %{room: params["room"], ln: ln})
    else
      conn
      |> redirect(to: "/ws")
    end
  end

  def logout(conn, _params) do
    conn
    |> clear_session()
    |> redirect(to: "/")
  end

  def auth(conn, params) do
    ln = params["ln"] || "en"
    Gettext.put_locale(PokerWeb.Gettext, ln)

    if String.length(params["name"]) > 30 or String.length(params["name"]) < 3 do
      conn
      |> put_flash(:error, gettext "Имя не может быть длиннее 30 символов и короче 3-ех")
      |> redirect(to: "/")
    end

    conn =
      conn
      |> put_session(:user, %{name: params["name"], id: System.unique_integer(), ln: ln})
      |> put_status(302)

    case params["room"] do
      nil ->
        conn
        |> redirect(to: "/ws")
      room ->
        conn
        |> redirect(to: "/ws/#{room}")
        # |> live_render(PokerWeb.RoomLive)
    end
  end
end
