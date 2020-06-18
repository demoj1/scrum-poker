defmodule PokerWeb.RoomLive do
  alias Phoenix.PubSub
  alias Poker.Coordinator
  use PokerWeb, :live_view
  import Phoenix.LiveView
  import PokerWeb.Gettext

  def mount(%{"room" => room}, session, socket) do
    PubSub.subscribe(Poker.PubSub, "room:#{room}")

    if session["user"] == nil do
      {:ok,
        socket
        |> put_flash(:info, gettext "Для входа в комнату необходимо ввести свое имя")
        |> redirect(to: "/?room=#{room}")
      }
    else
      Gettext.put_locale(PokerWeb.Gettext, session["user"][:ln] || "en")

      Coordinator.room_cast(:add_user_to_room, room, [session["user"]])
      room = Coordinator.room_call(:room_info, room)

      case room do
        nil ->
          {:ok,
            socket
            |> assign(user: session["user"])
            |> put_flash(:error, gettext "Комната не существует")
            |> redirect(to: "/ws")
          }
        room ->
          avg_score = room_avg_score(room)

          {:ok,
            socket
            |> assign(room: room)
            |> assign(avg_score: avg_score)
            |> assign(user: session["user"])
          }
      end
    end
  end

  @impl true
  def handle_event("select-card", %{"score" => score}, socket) do
    room = socket.assigns.room

    room_id = room.room_id
    user = socket.assigns.user

    if room[:open?] do
      {:noreply, put_flash(socket, :error, gettext "Невозможно изменить голос когда карты открыты")}
    else
      Coordinator.room_cast(:vote, room_id, [user, score])
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("open", _params, socket) do
    room_id = socket.assigns.room.room_id

    Coordinator.room_cast(:change_card_visibility, room_id, [true])

    Phoenix.PubSub.broadcast!(Poker.PubSub, "room:#{room_id}", :owner_open)

    {:noreply, socket}
  end

  @impl true
  def handle_event("close", _params, socket) do
    room_id = socket.assigns.room.room_id

    Coordinator.room_cast(:change_card_visibility, room_id, [false])

    Phoenix.PubSub.broadcast!(Poker.PubSub, "room:#{room_id}", :owner_close)

    {:noreply, socket}
  end

  @impl true
  def handle_event("open-self", %{"user" => user}, socket) do
    room_id = socket.assigns.room.room_id
    user_id = socket.assigns.user.id

    if user_id == user do
      Coordinator.room_cast(:open_self_card, room_id, [user_id])
    end

    {:noreply, socket}
  end

  @impl true
  def handle_event("start-timer", %{"minutes" => minutes}, socket) do
    room_id = socket.assigns.room.room_id
    seconds = String.to_float(minutes) * 60

    Coordinator.room_cast(:start_timer, room_id, [seconds])

    {:noreply, socket}
  end

  @impl true
  def handle_event("reset-vote", _params, socket) do
    room_id = socket.assigns.room.room_id

    Coordinator.room_cast(:reset_vote, room_id)

    {:noreply, socket}
  end

  @impl true
  def handle_event("reset-user-vote", %{"user_id" => user_id}, socket) do
    user_id = String.to_integer(user_id)
    room = socket.assigns.room
    room_id = room.room_id

    user = room.user_list |> Enum.find_value(fn
      {%{id: ^user_id} = user, _} -> user
      _ -> nil
    end)

    IO.inspect({user_id, room, user})

    Coordinator.room_cast(:reset_user_vote, room_id, [user])

    {:noreply, socket}
  end

  @impl true
  def handle_event("stop-timer", _params, socket) do
    room_id = socket.assigns.room.room_id

    Coordinator.room_cast(:stop_timer, room_id)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:update_room, room}, socket) do
    avg_score = room_avg_score(room)

    room =
      room
      |> update_in([:user_list], &Enum.sort_by(&1, fn {_, meta} ->
        Integer.parse(meta[:vote] || "0", 10)
      end))

    count_in_group =
      (room[:user_list] || [])
      |> Enum.group_by(fn {_, meta} -> meta[:vote] end)
      |> Enum.map(fn {g, l} -> {g, Enum.count(l)} end)

    IO.inspect(count_in_group)

    {:noreply,
      socket
      |> assign(count_in_group: count_in_group)
      |> assign(room: room)
      |> assign(avg_score: avg_score)
    }
  end

  @impl true
  def handle_info(:owner_open, socket) do
    {:noreply,
      socket
      |> put_flash(:info, gettext "Карты открыты")
    }
  end

  @impl true
  def handle_info(:owner_close, socket) do
    {:noreply,
      socket
      |> put_flash(:info, gettext "Карты закрыты")
    }
  end

  @impl true
  def handle_info(:room_timeout, socket) do
    {:noreply,
      socket
      |> put_flash(:info, gettext "Комната была закрыта в связи с бездействием")
      |> redirect(to: "/ws")}
  end

  defp room_avg_score(room) do
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

    (is_nil(sum_points) || count_vote == 0) && "---" || Float.round(sum_points / count_vote, 2)
  end
end
