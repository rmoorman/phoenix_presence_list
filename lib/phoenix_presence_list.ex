defmodule PhoenixPresenceList do
  @moduledoc """
  Documentation for PhoenixPresenceList.
  """

  @doc """
  Sync the given presence list using a diff of presence join and leave events.

  Returns the updated presence list. In case information on leaves and joins
  is needed, have a look at `apply_diff/2`.

  ## Examples

      iex> state = %{}
      iex> diff = %{joins: %{"foo" => %{metas: [%{phx_ref: "dWIi5WZTuJg="}]}}, leaves: %{}}
      iex> state = PhoenixPresenceList.sync_diff(state, diff)
      %{"foo" => %{metas: [%{phx_ref: "dWIi5WZTuJg="}]}}
      iex> diff = %{joins: %{"foo" => %{metas: [%{phx_ref: "U9NnWWscQRU="}]}}, leaves: %{}}
      iex> state = PhoenixPresenceList.sync_diff(state, diff)
      %{"foo" => %{metas: [%{phx_ref: "dWIi5WZTuJg="}, %{phx_ref: "U9NnWWscQRU="}]}}
      iex> diff = %{joins: %{}, leaves: %{"foo" => %{metas: [%{phx_ref: "U9NnWWscQRU="}]}}}
      iex> PhoenixPresenceList.sync_diff(state, diff)
      %{"foo" => %{metas: [%{phx_ref: "dWIi5WZTuJg="}]}}

  """
  def sync_diff(state, diff) do
    state
    |> apply_diff(diff)
    |> elem(0)
  end

  @doc """
  Sync the given presence list using a new presence list.

  Returns the new presence list. In case information on leaves and joins is
  needed, have a look at `apply_state/2`.
  """
  def sync_state(_state, new_state) do
    new_state
  end

  @doc """
  Apply a presence list to another presence list.

  Returns a tuple containing the new presence list along with two lists
  containing information about the joins and leaves that took place.

  ## Examples

      iex> state = %{}
      iex> new_state = %{"foo" => %{metas: [%{phx_ref: "dWIi5WZTuJg="}]}}
      iex> PhoenixPresenceList.apply_state(state, new_state)
      {%{"foo" => %{metas: [%{phx_ref: "dWIi5WZTuJg="}]}},
       [{"foo", nil, %{metas: [%{phx_ref: "dWIi5WZTuJg="}]}}], []}

  """
  def apply_state(state, new_state) do
    leaves =
      Enum.reduce(state, %{}, fn {key, presence}, leaves ->
        case new_state[key] do
          nil -> Map.put(leaves, key, presence)
          _ -> leaves
        end
      end)

    {joins, leaves} =
      Enum.reduce(new_state, {%{}, leaves}, fn {key, new_presence}, {joins, leaves} ->
        case state[key] do
          nil ->
            joins = Map.put(joins, key, new_presence)
            {joins, leaves}

          current_presence ->
            new_refs = Enum.map(new_presence.metas, & &1.phx_ref)
            cur_refs = Enum.map(current_presence.metas, & &1.phx_ref)
            joined_metas = Enum.filter(new_presence.metas, &(&1.phx_ref not in cur_refs))
            left_metas = Enum.filter(current_presence.metas, &(&1.phx_ref not in new_refs))

            joins =
              case joined_metas do
                [] -> joins
                joined_metas -> Map.put(joins, key, %{new_presence | metas: joined_metas})
              end

            leaves =
              case left_metas do
                [] -> leaves
                left_metas -> Map.put(joins, key, %{current_presence | metas: left_metas})
              end

            {joins, leaves}
        end
      end)

    apply_diff(state, %{joins: joins, leaves: leaves})
  end

  @doc """
  Apply the given joins and leaves diff to the given presence list.

  Returns a tuple containing the updated presence list as well as two lists
  with information about the joins and leaves that took place.

  ## Examples

      iex> state = %{}
      iex> diff = %{joins: %{"foo" => %{metas: [%{phx_ref: "dWIi5WZTuJg="}]}}, leaves: %{}}
      iex> PhoenixPresenceList.apply_diff(state, diff)
      {%{"foo" => %{metas: [%{phx_ref: "dWIi5WZTuJg="}]}},
       [{"foo", nil, %{metas: [%{phx_ref: "dWIi5WZTuJg="}]}}], []}

  """
  def apply_diff(state, %{joins: joins, leaves: leaves}) do
    {state, joined} = apply_diff_joins(state, joins)
    {state, left} = apply_diff_leaves(state, leaves)
    {state, joined, left}
  end

  defp apply_diff_joins(state, joins) do
    {state, joined} =
      Enum.reduce(joins, {state, []}, fn {key, new_presence}, {state, joined} ->
        current_presence = state[key]

        state =
          Map.update(state, key, new_presence, fn current_presence ->
            joined_refs = Enum.map(new_presence.metas, & &1.phx_ref)
            current_metas = Enum.filter(current_presence.metas, &(&1.phx_ref not in joined_refs))
            %{new_presence | metas: current_metas ++ new_presence.metas}
          end)

        updated_presence = state[key]

        join_info = {key, current_presence, updated_presence}

        {state, [join_info | joined]}
      end)

    {state, Enum.reverse(joined)}
  end

  defp apply_diff_leaves(state, leaves) do
    {state, left} =
      Enum.reduce(leaves, {state, []}, fn {key, left_presence}, {state, left} ->
        case state[key] do
          nil ->
            {state, left}

          current_presence ->
            refs_to_remove = Enum.map(left_presence.metas, & &1.phx_ref)

            filtered_metas =
              Enum.filter(current_presence.metas, &(&1.phx_ref not in refs_to_remove))

            updated_presence = %{current_presence | metas: filtered_metas}
            leave_info = {key, updated_presence, left_presence}

            state =
              case filtered_metas do
                [] -> Map.delete(state, key)
                _ -> Map.put(state, key, updated_presence)
              end

            {state, [leave_info | left]}
        end
      end)

    {state, Enum.reverse(left)}
  end
end
