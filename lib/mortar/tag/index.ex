defmodule Mortar.TagIndex do
  use Hume.Projection, store: Mortar.Event

  @type t :: %{
          binary() => %{
            count: non_neg_integer()
          }
        }

  @doc """
  Checks if a tag exists in the index.
  """
  def exists?(tag_name) do
    state = Hume.state(__MODULE__)
    get_in(state, [tag_name]) != nil
  end

  @doc """
  Returns the count of items tagged with the given tag name.
  """
  def count(tag_name) do
    state = Hume.state(__MODULE__)
    stat = get_in(state, [tag_name]) || %{count: 0}
    stat.count
  end

  @impl true
  def init_state(_via_tuple) do
    %{}
  end

  @impl true
  def handle_event({:add_tag, _subject, %{"tag" => tag_name}}, state) do
    stat = get_in(state, [tag_name]) || %{count: 0}
    stat = %{stat | count: stat[:count] + 1}
    {:ok, put_in(state, [tag_name], stat)}
  end

  def handle_event({:remove_tag, _subject, %{"tag" => tag_name}}, state) do
    stat = get_in(state, [tag_name]) || %{count: 0}
    stat = %{stat | count: max(stat[:count] - 1, 0)}

    if stat.count == 0 do
      # Remove the tag from the index if count is zero
      {_, state} = Map.pop(state, tag_name)
      {:ok, state}
    else
      {:ok, put_in(state, [tag_name], stat)}
    end
  end

  @impl true
  def last_snapshot(_via_tuple) do
    nil
  end

  @impl true
  def persist_snapshot(projection, snapshot) do
    :ok
  end
end
