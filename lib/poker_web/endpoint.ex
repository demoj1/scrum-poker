defmodule PokerWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :poker

  @session_options [
    store: :cookie,
    key: "_poker_session_store",
    encryption_salt: "oPElUX9FoEVJkyddZwsBeCwApI9BYB7RmzH8et4m1MKOhEZ9uHGZsrq1hYIpwn9h",
    signing_salt: "oPElUX9FoEVJkyddZwsBeCwApI9BYB7RmzH8et4m1MKOhEZ9uHGZsrq1hYIpwn9ht",
    key_length: 64,
    log: :debug,
    max_age: 4 * 7 * 24 * 60 * 60
  ]

  socket "/socket", PokerWeb.UserSocket,
    websocket: true,
    longpoll: false

  socket "/live", Phoenix.LiveView.Socket, websocket: [connect_info: [session: @session_options]]

  plug Plug.Static,
    at: "/",
    from: :poker,
    gzip: true,
    only: ~w(css fonts images js favicon.ico robots.txt sitemap.xml)

  if code_reloading? do
    socket "/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket
    plug Phoenix.LiveReloader
    plug Phoenix.CodeReloader
  end

  plug Plug.RequestId

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session, @session_options
  plug PokerWeb.Router
end
