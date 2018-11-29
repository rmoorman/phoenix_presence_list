# PhoenixPresenceList

Keep presence state up to date using broadcasted presence_diff data.

The functionality in this package is closely modelled after what the `syncState`
and `syncDiff` functions on `Presence` in `phoenix.js` provide.
Just like you would use `syncState` and `syncDiff` in the browser to keep the
presence list inside the browser up to date, you can use the supplied
`PhoenixPresenceList` module to keep a presence list inside a BEAM process up to
date.

## Usage example

Say you have a GenServer process that you would like to subscribe to presence
changes on a given topic and have that process keep track of the presence list.

Your GenServer module is named `FooWeb.Bar`, phoenix presence module is named
`FooWeb.Presence`, your endpoint is named `FooWeb.Endpoint` and you have a
channel with the topic `lobby` where you are tracking presence.

Then in case you could roughly do something like this in order to keep a
list of presences inside `FooWeb.Bar`:

```elixir
defmodule FooWeb.Bar do
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
    FooWeb.Endpoint.subscribe("lobby")
    initial_state = FooWeb.Presence.list("lobby")
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
```

For a more complete example have a look at [this test](test/phoenix_presence_list_integration_test.exs).


## Installation

This package can be installed by adding `phoenix_presence_list` to your list of
dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:phoenix_presence_list, "~> 0.1.0"}
  ]
end
```

## License

This project is licensed under the MIT License - see the [LICENSE.txt](LICENSE.txt) file for details
