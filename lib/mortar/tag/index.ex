defmodule Mortar.TagIndex do
  use Hume.Projection, store: Mortar.Event

  alias :trie, as: Trie
  alias Mortar.Snapshot

  @type t :: Trie.trie()

  @doc """
  Checks if a tag exists in the index.
  """
  def exists?(tag_name) do
    state = Hume.state(__MODULE__)
    Trie.is_key(String.to_charlist(tag_name), state)
  end

  @doc """
  Returns the count of items tagged with the given tag name.
  """
  def count(tag_name) do
    state = Hume.state(__MODULE__)
    Trie.fetch(String.to_charlist(tag_name), state)[:count] || 0
  end

  @doc """
  Returns a list of suggested tags based on the given prefix.
  Each suggestion is a tuple of `{tag_name, count}`.
  """
  def suggest(prefix, top_n \\ 10) do
    state = Hume.state(__MODULE__)
    prefix = String.to_charlist(prefix)

    Trie.fetch_keys_similar(prefix, state)
    |> Enum.map(fn {tag_charlist, stat} ->
      {to_string(tag_charlist), stat[:count]}
    end)
    |> Enum.sort_by(fn {_tag, count} -> -count end)
    |> Enum.take(top_n)
  end

  @impl true
  def init_state(_via_tuple) do
    Trie.new()
  end

  @impl true
  def handle_event({:add_tag, _subject, %{"tag" => tag_name}}, state) do
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

  def handle_event({:remove_tag, _subject, %{"tag" => tag_name}}, state) do
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

  @impl true
  def last_snapshot(_via_tuple) do
    Snapshot.get("tag_index")
  end

  @impl true
  def persist_snapshot(_projection, snapshot) do
    Snapshot.put("tag_index", snapshot)
  end
end
