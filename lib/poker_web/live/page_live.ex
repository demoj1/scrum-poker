defmodule PokerWeb.PageLive do
  alias Poker.Coordinator
  alias Phoenix.PubSub
  use PokerWeb, :live_view

  @impl true
  def mount(_params, session, socket) do
    case session["user"] do
      nil ->
        {:ok,
          socket
          |> put_flash(:info, "Необходимо ввести свое имя")
          |> redirect(to: "/")
        }

      user ->
        room_id = Coordinator.create_room(user, [])

        {:ok,
          socket
          |> assign(:user, user)
          |> redirect(to: "/ws/#{room_id}")
        }
    end
  end
end
