defmodule Mortar.Query do
  @moduledoc """
  Provides functionality to build and evaluate tag-based queries
  against a set of tags using logical conditions (AND, OR, NOT).

  A query can be constructed using the following functions:
    - `cond_and/2`: Creates an AND condition between two tags or conditions.
    - `cond_or/2`: Creates an OR condition between two tags or conditions.
    - `cond_not/1`: Creates a NOT condition for a tag or condition.

  The query can then be evaluated against a list of `Mortar.Tag` structs using `eval/2`.
  """

  alias Mortar.Tag

  @type tag :: binary()
  @type condition ::
          {:and, tag() | condition(), tag() | condition()}
          | {:or, tag() | condition(), tag() | condition()}
          | {:not, tag() | condition()}

  @type t :: condition() | tag()

  def cond_and(left, right)
      when (is_binary(left) or is_tuple(left)) and (is_binary(right) or is_tuple(right)),
      do: {:and, left, right}

  def cond_or(left, right)
      when (is_binary(left) or is_tuple(left)) and (is_binary(right) or is_tuple(right)),
      do: {:or, left, right}

  def cond_not(cond) when is_binary(cond) or is_tuple(cond), do: {:not, cond}

  @doc """
  Returns a query that requires all specified tags.
  """
  def require_tags(query) do
    tags =
      do_require_tags(query, [])
      |> Enum.uniq()

    ["__all__" | tags]
  end

  defp do_require_tags(tag, acc)
       when is_binary(tag) do
    [tag | acc]
  end

  defp do_require_tags({_, l_c, r_c}, acc)
       when is_tuple(l_c) and is_tuple(r_c) do
    acc = do_require_tags(l_c, acc)
    do_require_tags(r_c, acc)
  end

  defp do_require_tags({_, l_t, r_t}, acc)
       when is_binary(l_t) and is_binary(r_t) do
    [l_t | [r_t | acc]]
  end

  defp do_require_tags({_, l_t, r_c}, acc)
       when is_binary(l_t) and is_tuple(r_c) do
    do_require_tags(r_c, [l_t | acc])
  end

  defp do_require_tags({_, l_c, r_t}, acc)
       when is_tuple(l_c) and is_binary(r_t) do
    do_require_tags(l_c, [r_t | acc])
  end

  defp do_require_tags({_, t}, acc) when is_binary(t) do
    [t | acc]
  end

  defp do_require_tags({_, c}, acc) when is_tuple(c) do
    do_require_tags(c, acc)
  end

  @doc """
  Evaluates the query against the provided tags.
  """
  @spec eval(t(), [Tag.t()]) :: {:ok, [integer()]} | {:error, term()}
  def eval(query, tags) do
    tags = Map.new(tags, fn %Tag{name: name, bitmap_ref: bitmap_ref} -> {name, bitmap_ref} end)
    require_tags = require_tags(query)
    missing_tags = Enum.filter(require_tags, fn t -> not Map.has_key?(tags, t) end)

    if missing_tags != [] do
      {:error, {:missing_tags, missing_tags}}
    else
      do_eval(query, tags: tags) |> RoaringBitset.to_list()
    end
  end

  defp do_eval(t, ctx) when is_binary(t) do
    ctx[:tags][t]
  end

  defp do_eval({:and, l_t, r_t}, ctx) when is_binary(l_t) and is_binary(r_t) do
    {:ok, result} = RoaringBitset.intersection(ctx[:tags][l_t], ctx[:tags][r_t])
    result
  end

  defp do_eval({:and, {:not, n_t}, r_t}, ctx) when is_binary(n_t) and is_binary(r_t) do
    {:ok, result} = RoaringBitset.difference(ctx[:tags][r_t], ctx[:tags][n_t])
    result
  end

  defp do_eval({:and, {:not, n_c}, r_t}, ctx) when is_tuple(n_c) and is_binary(r_t) do
    {:ok, result} = RoaringBitset.difference(ctx[:tags][r_t], do_eval(n_c, ctx))
    result
  end

  defp do_eval({:and, l_c, r_t}, ctx) when is_tuple(l_c) and is_binary(r_t) do
    {:ok, result} = RoaringBitset.intersection(do_eval(l_c, ctx), ctx[:tags][r_t])
    result
  end

  defp do_eval({:and, l_t, {:not, n_t}}, ctx) when is_binary(l_t) and is_binary(n_t) do
    {:ok, result} = RoaringBitset.difference(ctx[:tags][l_t], ctx[:tags][n_t])
    result
  end

  defp do_eval({:and, l_t, {:not, n_c}}, ctx) when is_binary(l_t) and is_tuple(n_c) do
    {:ok, result} = RoaringBitset.difference(ctx[:tags][l_t], do_eval(n_c, ctx))
    result
  end

  defp do_eval({:and, l_t, r_c}, ctx) when is_binary(l_t) and is_tuple(r_c) do
    {:ok, result} = RoaringBitset.intersection(ctx[:tags][l_t], do_eval(r_c, ctx))
    result
  end

  defp do_eval({:and, l_c, r_c}, ctx) when is_tuple(l_c) and is_tuple(r_c) do
    {:ok, result} = RoaringBitset.intersection(do_eval(l_c, ctx), do_eval(r_c, ctx))
    result
  end

  defp do_eval({:or, l_t, r_t}, ctx) when is_binary(l_t) and is_binary(r_t) do
    {:ok, result} = RoaringBitset.union(ctx[:tags][l_t], ctx[:tags][r_t])
    result
  end

  defp do_eval({:or, l_c, r_t}, ctx) when is_tuple(l_c) and is_binary(r_t) do
    {:ok, result} = RoaringBitset.union(do_eval(l_c, ctx), ctx[:tags][r_t])
    result
  end

  defp do_eval({:or, l_t, r_c}, ctx) when is_binary(l_t) and is_tuple(r_c) do
    {:ok, result} = RoaringBitset.union(ctx[:tags][l_t], do_eval(r_c, ctx[:tags]))
    result
  end

  defp do_eval({:or, l_c, r_c}, ctx) when is_tuple(l_c) and is_tuple(r_c) do
    {:ok, result} = RoaringBitset.union(do_eval(l_c, ctx), do_eval(r_c, ctx))
    result
  end

  defp do_eval({:not, n_t}, ctx) when is_binary(n_t) do
    {:ok, result} = RoaringBitset.difference(ctx[:tags]["__all__"], ctx[:tags][n_t])
    result
  end
end
