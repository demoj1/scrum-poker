defmodule Poker.Coordinator do
  alias Poker.NameGenerator
  use GenServer

  def start_link(_params) do
    GenServer.start_link(__MODULE__, %{rooms: %{}}, name: __MODULE__)
  end

  def room_cast(action, room_id, params \\ []) do
    GenServer.cast(__MODULE__, {action, room_id, params})
  end

  def room_call(action, room_id, params \\ []) do
    GenServer.call(__MODULE__, {action, room_id, params})
  end

  @spec create_room(any, any) :: any
  def create_room(owner_id, room_opts) do
    GenServer.call(__MODULE__, {:create_room, owner_id, room_opts})
  end

  def get_room_list(user) do
    GenServer.call(__MODULE__, {:room_list, user})
  end

  def get_user_list(room_id) do
    GenServer.call(__MODULE__, {:get_user_list, room_id})
  end

  def stop_timer(room_id) do
    GenServer.cast(__MODULE__, {:stop_timer, room_id})
  end

  # =======================================================

  def handle_call({:room_info, room_id, []}, _from, state) do
    room_pid = state.rooms[room_id][:pid]
    if room_pid == nil do
      {:reply, nil, state}
    else
      {:reply, GenServer.call(room_pid, :room_info), state}
    end
  end

  def handle_call({:get_user_list, room_id}, _from, state) do
    room_pid = state.rooms[room_id][:pid]
    if room_pid == nil do
      {:reply, [], state}
    else
      {:reply, GenServer.call(room_pid, :get_users), state}
    end
  end

  def handle_call({:room_list, user}, _from, state) do
    rooms =
      state.rooms
      |> Enum.filter(fn {_k, v} -> MapSet.member?(v.users, user) end)

    {:reply, rooms, state}
  end

  def handle_cast({:vote, room_id, [user_id, score]}, state) do
    room_pid = state.rooms[room_id][:pid]
    GenServer.cast(room_pid, {:vote, user_id, score})

    {:noreply, state}
  end

  def handle_cast({:add_user_to_room, room_id, [user]}, state) do
    room_pid = state.rooms[room_id][:pid]
    unless room_pid == nil do
      GenServer.cast(room_pid, {:add_user, user})

      new_state = update_in(state, [:rooms, room_id], fn room ->
        Map.update(room, :users, MapSet.new([user]), fn users ->
          MapSet.put(users, user)
        end)
      end)

      Phoenix.PubSub.broadcast!(Poker.PubSub, "rooms", :update_rooms)

      {:noreply, new_state}
    else
      {:noreply, state}
    end
  end

  def handle_cast({:change_card_visibility, room_id, [flag]}, state) do
    room_pid = state.rooms[room_id][:pid]
    GenServer.cast(room_pid, {:change_card_visibility, flag})

    {:noreply, state}
  end

  def handle_call({:create_room, owner_id, room_opts}, _from, state) do
    room_id = :crypto.strong_rand_bytes(64) |> Base.url_encode64 |> binary_part(0, 64)
    room_name = room_opts[:name] || NameGenerator.get_name

    {:ok, pid} = GenServer.start_link(Poker.Room, {
      owner_id,
      room_id,
      room_name,
      [user_list: %{owner_id => %{}}]
    }, name: room_id |> String.to_atom())

    new_state = put_in(state, [:rooms, room_id], %{
      pid: pid,
      name: room_name,
      owner: owner_id,
      users: MapSet.new()
    })

    Phoenix.PubSub.broadcast!(Poker.PubSub, "rooms", :update_rooms)

    {:reply, room_id, new_state}
  end

  def handle_cast({:open_self_card, room_id, [user_id]}, state) do
    room_pid = state.rooms[room_id][:pid]
    GenServer.cast(room_pid, {:open_self_card, user_id})

    {:noreply, state}
  end

  def handle_cast({:start_timer, room_id, [seconds]}, state) do
    room_pid = state.rooms[room_id][:pid]
    GenServer.cast(room_pid, {:start_timer, seconds})

    {:noreply, state}
  end

  def handle_cast({:stop_timer, room_id}, state) do
    room_pid = state.rooms[room_id][:pid]
    GenServer.cast(room_pid, :stop_timer)

    {:noreply, state}
  end

  def handle_cast({:reset_vote, room_id, []}, state) do
    room_pid = state.rooms[room_id][:pid]
    GenServer.cast(room_pid, :reset_vote)

    {:noreply, state}
  end

  def handle_cast({:reset_user_vote, room_id, [user]}, state) do
    room_pid = state.rooms[room_id][:pid]
    GenServer.cast(room_pid, {:reset_user_vote, user})

    {:noreply, state}
  end
end

defmodule Poker.Room do
  use GenServer

  @impl true
  def init({owner_id, room_id, room_name, room_opts}) do
    opts = Enum.into(room_opts, %{})

    {:ok, Map.merge(%{
      name: room_name,
      room_id: room_id,
      owner_id: owner_id,
      open?: false,
      user_list: %{}
    }, opts)}
  end

  @impl true
  def handle_call(:room_info, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call(:get_users, _from, state) do
    {:reply, state.user_list, state}
  end

  @impl true
  def handle_cast({:vote, user, score}, state) do
    new_state = update_in(state, [:user_list, user], fn user_opts ->
      Map.put(user_opts, :vote, score)
    end)

    Phoenix.PubSub.broadcast(Poker.PubSub, "room:#{state.room_id}", {:update_room, new_state})

    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:add_user, user}, state) do
    new_state = update_in(state, [:user_list], fn user_list ->
      Map.put_new(user_list, user, %{})
    end)

    Phoenix.PubSub.broadcast(Poker.PubSub, "room:#{state.room_id}", {:update_room, new_state})

    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:change_card_visibility, flag}, state) do
    new_state = Map.update!(state, :open?, fn _ -> flag end)

    Phoenix.PubSub.broadcast(Poker.PubSub, "room:#{state.room_id}", {:update_room, new_state})

    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:open_self_card, user}, state) do
    new_state = update_in(state, [:user_list, user], fn opts ->
      Map.update(opts, :open?, true, fn old -> not old end)
    end)

    Phoenix.PubSub.broadcast(Poker.PubSub, "room:#{state.room_id}", {:update_room, new_state})

    {:noreply, new_state}
  end

  @impl true
  def handle_cast(:reset_vote, state) do
    new_state =
      state
      |> update_in([:user_list], fn users ->
        users
        |> Enum.map(fn {user_name, opts} -> {user_name, Map.drop(opts, [:vote, :open?])} end)
        |> Enum.into(%{})
      end)
      |> Map.put(:open?, false)

    Phoenix.PubSub.broadcast(Poker.PubSub, "room:#{state.room_id}", {:update_room, new_state})

    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:start_timer, seconds}, state) do
    ref = make_ref()
    :timer.send_after(1000, self(), {:tick, ref})

    new_state =
      state
      |> Map.put(:timer, timer_to_view(seconds, seconds))
      |> Map.put(:timer_ref, ref)

    Phoenix.PubSub.broadcast(Poker.PubSub, "room:#{state.room_id}", {:update_room, new_state})

    {:noreply, new_state}
  end

  @impl true
  def handle_cast(:stop_timer, state) do
    new_state =
      state
      |> Map.drop([:timer, :timer_ref])

    Phoenix.PubSub.broadcast(Poker.PubSub, "room:#{state.room_id}", {:update_room, new_state})

    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:reset_user_vote, user}, state) do
    new_state =
      state
      |> update_in([:user_list, user, :vote], fn _ -> nil end)

    Phoenix.PubSub.broadcast(Poker.PubSub, "room:#{state.room_id}", {:update_room, new_state})

    {:noreply, new_state}
  end

  @impl true
  def handle_info({:tick, ref}, state) do
    case {state[:timer], state[:timer_ref] == ref} do
      {nil, _} -> {:noreply, state}
      {_, false} -> {:noreply, state}
      {timer, true} ->
        %{
          current_seconds: current_seconds,
          total_seconds: total_seconds
        } = timer

        if current_seconds - 1 <= 0 do
          new_state = Map.put(state, :timer, nil)
          Phoenix.PubSub.broadcast(Poker.PubSub, "room:#{state.room_id}", {:update_room, new_state})
          {:noreply, new_state}
        else
          :timer.send_after(1000, self(), {:tick, ref})

          new_state = Map.put(state, :timer, timer_to_view(current_seconds - 1, total_seconds))

          Phoenix.PubSub.broadcast(Poker.PubSub, "room:#{state.room_id}", {:update_room, new_state})

          {:noreply, new_state}
        end
    end
  end

  defp timer_to_view(current_seconds, total_seconds) do

    minutes = floor(current_seconds / 60)
    seconds = current_seconds - minutes * 60.0

    %{
      seconds: seconds,
      minutes: minutes,
      total_seconds: total_seconds,
      current_seconds: current_seconds
    }
  end
end
