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
        |> redirect(to: "/?next=#{room}")
      }
    else
      Coordinator.add_user_to_room(room, session["user"])
      room = Coordinator.room_info(room)

      count_vote =
        room.user_list
        |> Enum.filter(fn {_, v} -> v[:vote] != nil end)
        |> Enum.count()

      sum_points =
        room.user_list
        |> Enum.filter(fn {_, v} ->
          v[:vote] != nil and Integer.parse(v[:vote]) != :error
        end)
        |> Enum.map(fn {_, v} -> String.to_integer(v[:vote]) end)
        |> Enum.sum()

      {:ok,
        socket
        |> assign(room: room)
        |> assign(avg_score: (is_nil(sum_points) || count_vote == 0) && "---" || sum_points / count_vote)
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
  def handle_event("start-timer", %{"minutes" => minutes}, socket) do
    room_id = socket.assigns.room.room_id
    seconds = String.to_float(minutes) * 60

    Coordinator.start_timer(room_id, seconds)

    {:noreply, socket}
  end

  @impl true
  def handle_event("reset-vote", _params, socket) do
    room_id = socket.assigns.room.room_id

    Coordinator.reset_vote(room_id)

    {:noreply, socket}
  end

  @impl true
  def handle_event("stop-timer", _params, socket) do
    room_id = socket.assigns.room.room_id

    Coordinator.stop_timer(room_id)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:update_room, room}, socket) do
    count_vote =
      room.user_list
      |> Enum.filter(fn {_, v} -> v[:vote] != nil end)
      |> Enum.count()

    sum_points =
      room.user_list
      |> Enum.filter(fn {_, v} ->
        v[:vote] != nil and Integer.parse(v[:vote]) != :error
      end)
      |> Enum.map(fn {_, v} -> String.to_integer(v[:vote]) end)
      |> Enum.sum()

    {:noreply,
      socket
      |> assign(room: room)
      |> assign(avg_score: (is_nil(sum_points) || count_vote == 0) && "---" || sum_points / count_vote)
    }
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
