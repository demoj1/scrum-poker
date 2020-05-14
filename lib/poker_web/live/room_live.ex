defmodule PokerWeb.RoomLive do
  alias Phoenix.PubSub
  alias Poker.Coordinator
  use PokerWeb, :live_view

  @impl true
  def mount(%{"room" => room}, session, socket) do
    PubSub.subscribe(Poker.PubSub, "room:#{room}")

    if session["user"] == nil do
      {:ok,
        socket
        |> put_flash(:info, "Для входа в комнату необходимо ввести свое имя")
        |> redirect(to: "/")
      }
    else
      Coordinator.add_user_to_room(room, session["user"])

      {:ok,
        socket
        |> assign(room: Coordinator.room_info(room))
        |> assign(user: session["user"])
      }
    end
  end

  @impl true
  def handle_event("select-card", %{"score" => score}, socket) do
    room_id = socket.assigns.room.room_id
    user_id = socket.assigns.user

    Coordinator.user_vote(room_id, user_id, score)

    {:noreply, socket}
  end

  @impl true
  def handle_event("open", _params, socket) do
    room_id = socket.assigns.room.room_id

    Coordinator.change_card_visibility(room_id, true)

    Phoenix.PubSub.broadcast!(Poker.PubSub, "room:#{room_id}", :owner_open)

    {:noreply, socket}
  end

  @impl true
  def handle_event("close", _params, socket) do
    room_id = socket.assigns.room.room_id

    Coordinator.change_card_visibility(room_id, false)

    Phoenix.PubSub.broadcast!(Poker.PubSub, "room:#{room_id}", :owner_close)

    {:noreply, socket}
  end

  @impl true
  def handle_event("open-self", %{"user" => user}, socket) do
    room_id = socket.assigns.room.room_id
    user_id = socket.assigns.user

    if user_id == user do
      Coordinator.open_self_card(room_id, user_id)
    end

    {:noreply, socket}
  end

  @impl true
  def handle_event("reset-vote", _params, socket) do
    room_id = socket.assigns.room.room_id

    Coordinator.reset_vote(room_id)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:update_room, room}, socket) do
    {:noreply, assign(socket, room: room)}
  end

  @impl true
  def handle_info(:owner_open, socket) do
    {:noreply,
      socket
      |> put_flash(:info, "Карты открыты")
    }
  end

  @impl true
  def handle_info(:owner_close, socket) do
    {:noreply,
      socket
      |> put_flash(:info, "Карты закрыты")
    }
  end
end
