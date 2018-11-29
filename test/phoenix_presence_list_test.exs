defmodule PhoenixPresenceListTest do
  use ExUnit.Case
  doctest PhoenixPresenceList

  @fixtures %{
    joins: %{"u1" => %{metas: [%{id: 1, phx_ref: "1.2"}]}},
    leaves: %{"u2" => %{metas: [%{id: 2, phx_ref: "2"}]}},
    state: %{
      "u1" => %{metas: [%{id: 1, phx_ref: "1"}]},
      "u2" => %{metas: [%{id: 2, phx_ref: "2"}]},
      "u3" => %{metas: [%{id: 3, phx_ref: "3"}]}
    }
  }

  describe "sync_state" do
    test "syncs empty state" do
      new_state = %{"u1" => %{metas: [%{id: 1, phx_ref: "1"}]}}
      state = %{}

      state = PhoenixPresenceList.sync_state(state, new_state)
      assert state == new_state
    end

    test "syncs filled state" do
      new_state = @fixtures.state
      state = %{"u4" => %{metas: [%{id: 4, phx_ref: "4"}]}}

      state = PhoenixPresenceList.sync_state(state, new_state)
      assert state == new_state
    end
  end

  describe "apply_state" do
    test "joined contains new presences and left contains left presences" do
      new_state = @fixtures.state
      state = %{"u4" => %{metas: [%{id: 4, phx_ref: "4"}]}}

      {state, joined, left} = PhoenixPresenceList.apply_state(state, new_state)
      assert state == new_state

      assert joined == [
               {"u1", nil, %{metas: [%{id: 1, phx_ref: "1"}]}},
               {"u2", nil, %{metas: [%{id: 2, phx_ref: "2"}]}},
               {"u3", nil, %{metas: [%{id: 3, phx_ref: "3"}]}}
             ]

      assert left == [
               {"u4", %{metas: []}, %{metas: [%{id: 4, phx_ref: "4"}]}}
             ]
    end

    test "joined contains only newly added metas" do
      new_state = %{"u3" => %{metas: [%{id: 3, phx_ref: "3"}, %{id: 3, phx_ref: "3.new"}]}}
      state = %{"u3" => %{metas: [%{id: 3, phx_ref: "3"}]}}

      {state, joined, left} = PhoenixPresenceList.apply_state(state, new_state)
      assert state == new_state

      assert joined == [
               {"u3", %{metas: [%{id: 3, phx_ref: "3"}]},
                %{metas: [%{id: 3, phx_ref: "3"}, %{id: 3, phx_ref: "3.new"}]}}
             ]

      assert left == []
    end
  end

  describe "sync_diff" do
    test "syncs empty state" do
      state = %{}
      joins = %{"u1" => %{metas: [%{id: 1, phx_ref: "1"}]}}
      diff = %{joins: joins, leaves: %{}}

      state = PhoenixPresenceList.sync_diff(state, diff)
      assert state == joins
    end

    test "removes presence when meta is empty and adds additional meta" do
      state = @fixtures.state
      diff = %{joins: @fixtures.joins, leaves: @fixtures.leaves}

      state = PhoenixPresenceList.sync_diff(state, diff)

      assert state == %{
               "u1" => %{metas: [%{id: 1, phx_ref: "1"}, %{id: 1, phx_ref: "1.2"}]},
               "u3" => %{metas: [%{id: 3, phx_ref: "3"}]}
             }
    end

    test "removes meta while leaving key if other metas exist" do
      state = %{
        "u1" => %{metas: [%{id: 1, phx_ref: "1"}, %{id: 1, phx_ref: "1.2"}]}
      }

      diff = %{joins: %{}, leaves: %{"u1" => %{metas: [%{id: 1, phx_ref: "1"}]}}}

      state = PhoenixPresenceList.sync_diff(state, diff)
      assert state == %{"u1" => %{metas: [%{id: 1, phx_ref: "1.2"}]}}
    end
  end
end
