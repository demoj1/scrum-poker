defmodule Poker.Coordinator do
  alias Poker.NameGenerator
  use GenServer

  def start_link(_params) do
    GenServer.start_link(__MODULE__, %{rooms: %{}}, name: __MODULE__)
  end

  @spec create_room(any, any) :: any
  def create_room(owner_id, room_opts) do
    GenServer.call(__MODULE__, {:create_room, owner_id, room_opts})
  end

  def add_user_to_room(room_id, user_id) do
    GenServer.cast(__MODULE__, {:add_user_to_room, room_id, user_id})
  end

  def get_room_list(user_id) do
    GenServer.call(__MODULE__, {:room_list, user_id})
  end

  def get_user_list(room_id) do
    GenServer.call(__MODULE__, {:get_user_list, room_id})
  end

  def room_info(room_id) do
    GenServer.call(__MODULE__, {:room_info, room_id})
  end

  def user_vote(room_id, user_id, score) do
    GenServer.cast(__MODULE__, {:vote, room_id, user_id, score})
  end

  def change_card_visibility(room_id, flag) do
    GenServer.cast(__MODULE__, {:change_card_visibility, room_id, flag})
  end

  def open_self_card(room_id, user_id) do
    GenServer.cast(__MODULE__, {:open_self_card, room_id, user_id})
  end

  def reset_vote(room_id) do
    GenServer.cast(__MODULE__, {:reset_vote, room_id})
  end

  # =======================================================

  def handle_call({:room_info, room_id}, _from, state) do
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

  def handle_call({:room_list, user_id}, _from, state) do
    rooms =
      state.rooms
      |> Enum.filter(fn {_k, v} -> MapSet.member?(v.users, user_id) end)

    {:reply, rooms, state}
  end

  def handle_cast({:vote, room_id, user_id, score}, state) do
    room_pid = state.rooms[room_id][:pid]
    GenServer.cast(room_pid, {:vote, user_id, score})

    {:noreply, state}
  end

  def handle_cast({:add_user_to_room, room_id, user_id}, state) do
    room_pid = state.rooms[room_id][:pid]
    unless room_pid == nil do
      GenServer.cast(room_pid, {:add_user, user_id})

      new_state = update_in(state, [:rooms, room_id], fn room ->
        Map.update(room, :users, MapSet.new([user_id]), fn users ->
          MapSet.put(users, user_id)
        end)
      end)

      Phoenix.PubSub.broadcast!(Poker.PubSub, "rooms", {:update_rooms, new_state.rooms})

      {:noreply, new_state}
    else
      {:noreply, state}
    end
  end

  def handle_cast({:change_card_visibility, room_id, flag}, state) do
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

  def handle_cast({:open_self_card, room_id, user_id}, state) do
    room_pid = state.rooms[room_id][:pid]
    GenServer.cast(room_pid, {:open_self_card, user_id})

    {:noreply, state}
  end

  def handle_cast({:reset_vote, room_id}, state) do
    room_pid = state.rooms[room_id][:pid]
    GenServer.cast(room_pid, :reset_vote)

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
  def handle_cast({:vote, user_id, score}, state) do
    new_state = update_in(state, [:user_list, user_id], fn user_opts ->
      Map.put(user_opts, :vote, score)
    end)

    Phoenix.PubSub.broadcast(Poker.PubSub, "room:#{state.room_id}", {:update_room, new_state})

    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:add_user, user_id}, state) do
    new_state = update_in(state, [:user_list], fn user_list ->
      Map.put_new(user_list, user_id, %{})
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
  def handle_cast({:open_self_card, user_id}, state) do
    new_state = update_in(state, [:user_list, user_id], fn opts ->
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
end
