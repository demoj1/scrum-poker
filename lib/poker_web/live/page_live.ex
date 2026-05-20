defmodule PokerWeb.PageLive do
  alias Poker.Coordinator
  alias Phoenix.PubSub
  use PokerWeb, :live_view

  @impl true
  def mount(_params, session, socket) do
    Gettext.put_locale(PokerWeb.Gettext, "ru")
    PubSub.subscribe(Poker.PubSub, "rooms")

    case session["user"] do
      nil ->
        {:ok,
          socket
          |> put_flash(:info, "Необходимо ввести свое имя")
          |> redirect(to: "/")
        }

      user ->
        {:ok,
          socket
          |> assign(:user, user)
          |> assign(:room_list, Coordinator.get_room_list(user))
        }
    end
  end

  @impl true
  def handle_event("create", _params, socket) do
    user = socket.assigns.user
    room_id = Coordinator.create_room(user, [])

    {:noreply,
      socket
      |> redirect(to: "/ws/#{room_id}")
    }
  end

  @impl true
  def handle_info(:update_rooms, socket) do
    {:noreply, assign(socket, :room_list, Coordinator.get_room_list(socket.assigns.user))}
  end
end
