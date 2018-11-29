defmodule PhoenixPresenceListIntegrationTest do
  use ExUnit.Case, async: true

  defmodule MyDummyServer do
    use GenServer
    import PhoenixPresenceList, only: [apply_diff: 2]
    alias Phoenix.Socket.Broadcast

    def start_link(opts) do
      GenServer.start_link(__MODULE__, opts)
    end

    def list(server) do
      GenServer.call(server, :list)
    end

    def init(opts) do
      endpoint = Keyword.fetch!(opts, :endpoint)
      presence = Keyword.fetch!(opts, :presence)
      topic = Keyword.fetch!(opts, :topic)

      endpoint.subscribe(topic)
      initial_state = presence.list(topic)
      {:ok, initial_state}
    end

    def handle_call(:list, _from, state) do
      {:reply, Map.keys(state) |> MapSet.new(), state}
    end

    def handle_info(%Broadcast{event: "presence_diff", payload: payload}, state) do
      {state, _joined, _left} = apply_diff(state, payload)
      {:noreply, state}
    end
  end

  defmodule MyNoopServer do
    use GenServer
    def start_link(), do: GenServer.start_link(__MODULE__, [])
    def init(_opts), do: {:ok, nil}
  end

  defmodule MyEndpoint do
    use Phoenix.Endpoint, otp_app: :phoenix_presence_list

    def init(_, config) do
      pubsub = [adapter: Phoenix.PubSub.PG2, name: MyPubSub]
      {:ok, Keyword.put(config, :pubsub, pubsub)}
    end
  end

  defmodule MyPresence do
    use Phoenix.Presence, otp_app: :phoenix_presence_list
  end

  Application.put_env(:phoenix_presence_list, MyPresence, pubsub_server: MyPubSub)

  setup_all do
    {:ok, _} = MyEndpoint.start_link()
    assert {:ok, _} = MyPresence.start_link()
    :ok
  end

  setup config do
    extra_config = [topic: to_string(config.test)]
    {:ok, extra_config}
  end

  test "Presence synchronization using presence_diff broadcasts", %{topic: topic} do
    assert %{} = MyPresence.list(topic)

    {:ok, u1pid1} = start_supervised(%{id: :u1pid1, start: {MyNoopServer, :start_link, []}})
    {:ok, _} = MyPresence.track(u1pid1, topic, "u1", %{})
    assert %{"u1" => _} = MyPresence.list(topic)

    {:ok, server} =
      start_supervised({MyDummyServer, endpoint: MyEndpoint, presence: MyPresence, topic: topic})

    assert MyDummyServer.list(server) == MapSet.new(["u1"])

    {:ok, u1pid2} = start_supervised(%{id: :u1pid2, start: {MyNoopServer, :start_link, []}})
    {:ok, _} = MyPresence.track(u1pid2, topic, "u1", %{})
    assert %{"u1" => _} = MyPresence.list(topic)
    assert MyDummyServer.list(server) == MapSet.new(["u1"])

    {:ok, u2pid1} = start_supervised(%{id: :u2pid1, start: {MyNoopServer, :start_link, []}})
    {:ok, _} = MyPresence.track(u2pid1, topic, "u2", %{})
    assert %{"u1" => _, "u2" => _} = MyPresence.list(topic)
    assert MyDummyServer.list(server) == MapSet.new(["u1", "u2"])

    stop_supervised(:u1pid1)
    assert %{"u1" => _, "u2" => _} = MyPresence.list(topic)
    assert MyDummyServer.list(server) == MapSet.new(["u1", "u2"])

    stop_supervised(:u2pid1)
    assert %{"u1" => _} = MyPresence.list(topic)
    assert MyDummyServer.list(server) == MapSet.new(["u1"])

    stop_supervised(:u1pid2)
    assert %{} = MyPresence.list(topic)
    assert MyDummyServer.list(server) == MapSet.new([])
  end
end
