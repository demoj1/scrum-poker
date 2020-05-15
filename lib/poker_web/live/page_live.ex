defmodule PokerWeb.PageLive do
  alias Poker.Coordinator
  alias Phoenix.PubSub
  use PokerWeb, :live_view

  @impl true
  def mount(params, session, socket) do
    if connected?(socket), do: PubSub.subscribe(Poker.PubSub, "rooms")

    rooms = Coordinator.get_room_list(session["user"])
    {:ok,
      socket
      |> assign(:room_list, rooms)
      |> assign(:user, session["user"])
    }
  end

  @impl true
  def handle_info(:update_rooms, socket) do
    rooms = Coordinator.get_room_list(socket.assigns.user)
    {:noreply, assign(socket, :room_list, rooms)}
  end

  @impl true
  def handle_event("create", _params, socket) do
    room_id = Coordinator.create_room(socket.assigns.user, [])
    {:noreply, redirect(socket, to: "/ws/#{room_id}")}
  end
end
