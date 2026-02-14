defmodule Mortar.TagIndex do
  use Hume.Projection, store: Mortar.Event

  alias :trie, as: Trie
  alias Mortar.Snapshot

  @type t :: Trie.trie()

  @doc """
  Checks if a tag exists in the index.
  """
  def exists?(non_tag) when non_tag in ["", nil] do
    false
  end

  def exists?(tag_name) do
    state = Hume.state(__MODULE__)
    Trie.is_key(String.to_charlist(tag_name), state)
  end

  @doc """
  Returns the count of items tagged with the given tag name.

  If no tag name is provided, returns the total count of all tagged items.
  """
  def count(tag_name) do
    state = Hume.state(__MODULE__)
    Trie.fetch(String.to_charlist(tag_name), state)[:count] || 0
  end

  def count() do
    state = Hume.state(__MODULE__)
    Trie.fetch(String.to_charlist("__all__"), state)[:count] || 0
  end

  @doc """
  Returns a list of suggested tags based on the given prefix.
  Each suggestion is a tuple of `{tag_name, count}`.
  """
  def suggest(prefix)

  def suggest("") do
    state = Hume.state(__MODULE__)

    Trie.fold(
      fn key, val, acc -> [{to_string(key), val[:count]} | acc] end,
      [],
      state
    )
  end

  def suggest(prefix) do
    state = Hume.state(__MODULE__)
    prefix = String.to_charlist(prefix)

    if Trie.is_prefix(prefix, state) do
      Trie.to_list_similar(prefix, state)
      |> Enum.map(fn {key, val} -> {to_string(key), val[:count]} end)
    else
      []
    end
  end

  @doc """
  Returns a list of tags filtered by the given count condition.

  The condition should be a tuple of `{op, th_rate}` where `op` is
  either `:>=` or `:<`, and `th_rate` is a float between 0.0 and 1.0
  representing the threshold rate of total medias.
  Each entry is a tuple of `{tag_name, count}`.
  """
  def filter_by_count({op, th_rate} = cond)
      when op in [:>=, :<] and th_rate > 0.0 and th_rate <= 1.0 do
    state = Hume.state(__MODULE__)
    total_medias = Trie.fetch(String.to_charlist("__all__"), state)[:count] || 0

    closure =
      case cond do
        {:>=, th_rate} when th_rate > 0.0 and th_rate <= 1.0 ->
          th = (total_medias * th_rate) |> round()
          fn count -> count >= th end

        {:<, th_rate} when th_rate > 0.0 and th_rate <= 1.0 ->
          th = (total_medias * th_rate) |> round()
          fn count -> count < th end
      end

    Trie.fold(
      fn key, val, acc ->
        count = val[:count]

        if closure.(count) do
          [{to_string(key), count} | acc]
        else
          acc
        end
      end,
      [],
      state
    )
  end

  @impl true
  def init_state(_via_tuple) do
    Trie.new()
  end

  @impl true
  def handle_event({:add_tag, "", _}, state) do
    {:ok, state}
  end

  def handle_event({:add_tag, tag_name, _}, state) do
    tag_name = String.to_charlist(tag_name)

    state =
      Trie.update(
        tag_name,
        fn stat ->
          put_in(stat, [:count], stat[:count] + 1)
        end,
        [count: 1],
        state
      )

    {:ok, state}
  end

  def handle_event({:remove_tag, "", _}, state) do
    {:ok, state}
  end

  def handle_event({:remove_tag, tag_name, _}, state) do
    tag_name = String.to_charlist(tag_name)

    state =
      Trie.update(
        tag_name,
        fn stat ->
          put_in(stat, [:count], stat[:count] - 1)
        end,
        [count: 0],
        state
      )

    if Trie.fetch(tag_name, state)[:count] == 0 do
      # Remove the tag from the index if count is zero
      {:ok, Trie.erase(tag_name, state)}
    else
      {:ok, state}
    end
  end

  def handle_event({:upload_media, _subject, _}, state) do
    state =
      Trie.update(
        "__all__" |> String.to_charlist(),
        fn stat ->
          put_in(stat, [:count], stat[:count] + 1)
        end,
        [count: 1],
        state
      )

    {:ok, state}
  end

  def handle_event(_event, state) do
    {:ok, state}
  end

  @impl true
  def last_snapshot(_via_tuple) do
    Snapshot.get("tag_index")
  end

  @impl true
  def persist_snapshot(_projection, snapshot) do
    Snapshot.put("tag_index", snapshot)
  end
end
