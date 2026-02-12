defmodule Mortar.QueryTest do
  use ExUnit.Case, async: true

  alias Mortar.Query
  alias Mortar.Tag

  describe "cond_and/2" do
    test "creates AND condition with two tags" do
      assert Query.cond_and("tag1", "tag2") == {:and, "tag1", "tag2"}
    end

    test "creates AND condition with tag and condition" do
      inner = {:or, "tag1", "tag2"}
      assert Query.cond_and("tag3", inner) == {:and, "tag3", inner}
    end

    test "creates AND condition with two conditions" do
      left = {:or, "tag1", "tag2"}
      right = {:not, "tag3"}
      assert Query.cond_and(left, right) == {:and, left, right}
    end
  end

  describe "cond_or/2" do
    test "creates OR condition with two tags" do
      assert Query.cond_or("tag1", "tag2") == {:or, "tag1", "tag2"}
    end

    test "creates OR condition with tag and condition" do
      inner = {:and, "tag1", "tag2"}
      assert Query.cond_or("tag3", inner) == {:or, "tag3", inner}
    end

    test "creates OR condition with two conditions" do
      left = {:and, "tag1", "tag2"}
      right = {:not, "tag3"}
      assert Query.cond_or(left, right) == {:or, left, right}
    end
  end

  describe "cond_not/1" do
    test "creates NOT condition with tag" do
      assert Query.cond_not("tag1") == {:not, "tag1"}
    end

    test "creates NOT condition with condition" do
      inner = {:and, "tag1", "tag2"}
      assert Query.cond_not(inner) == {:not, inner}
    end
  end

  describe "require_tags/1" do
    test "extracts tags from AND condition" do
      query = {:and, "tag1", "tag2"}
      assert Query.require_tags(query) == ["__all__", "tag1", "tag2"]
    end

    test "extracts tags from OR condition" do
      query = {:or, "tag1", "tag2"}
      assert Query.require_tags(query) == ["__all__", "tag1", "tag2"]
    end

    test "extracts tags from NOT condition" do
      query = {:not, "tag1"}
      assert Query.require_tags(query) == ["__all__", "tag1"]
    end

    test "extracts tags from nested conditions" do
      query = {:and, {:or, "tag1", "tag2"}, "tag3"}
      tags = Query.require_tags(query)
      assert Enum.sort(tags) == ["__all__", "tag1", "tag2", "tag3"]
    end

    test "removes duplicate tags" do
      query = {:and, "tag1", {:or, "tag1", "tag2"}}
      tags = Query.require_tags(query)
      assert Enum.sort(tags) == ["__all__", "tag1", "tag2"]
    end
  end

  describe "eval/2" do
    setup do
      {:ok, bitmap1} = RoaringBitset.new()
      {:ok, bitmap2} = RoaringBitset.new()
      {:ok, bitmap3} = RoaringBitset.new()

      Enum.each([1, 2, 3, 4, 5], &RoaringBitset.insert(bitmap1, &1))
      Enum.each([3, 4, 5, 6, 7], &RoaringBitset.insert(bitmap2, &1))
      Enum.each([1, 3, 5, 7, 9], &RoaringBitset.insert(bitmap3, &1))

      {:ok, all} = RoaringBitset.from_list([1, 2, 3, 4, 5, 6, 7, 8, 9])

      tags = [
        %Tag{name: "tag1", bitmap_ref: bitmap1},
        %Tag{name: "tag2", bitmap_ref: bitmap2},
        %Tag{name: "tag3", bitmap_ref: bitmap3},
        %Tag{name: "__all__", bitmap_ref: all}
      ]

      {:ok, tags: tags}
    end

    test "returns error when tags are missing", %{tags: tags} do
      query = {:and, "tag1", "missing_tag"}
      assert {:error, _error} = Query.eval(query, tags)
    end

    test "returns error with multiple missing tags", %{tags: tags} do
      query = {:and, "missing1", {:or, "tag1", "missing2"}}
      assert {:error, _error} = Query.eval(query, tags)
    end

    test "evaluates AND with two tags", %{tags: tags} do
      query = {:and, "tag1", "tag2"}
      assert {:ok, result} = Query.eval(query, tags)
      assert Enum.sort(result) == [3, 4, 5]
    end

    test "evaluates OR with two tags", %{tags: tags} do
      query = {:or, "tag1", "tag2"}
      assert {:ok, result} = Query.eval(query, tags)
      assert Enum.sort(result) == [1, 2, 3, 4, 5, 6, 7]
    end

    test "evaluates AND with NOT on right", %{tags: tags} do
      query = {:and, "tag1", {:not, "tag2"}}
      assert {:ok, result} = Query.eval(query, tags)
      assert Enum.sort(result) == [1, 2]
    end

    test "evaluates AND with NOT on left", %{tags: tags} do
      query = {:and, {:not, "tag2"}, "tag1"}
      assert {:ok, result} = Query.eval(query, tags)
      assert Enum.sort(result) == [1, 2]
    end

    test "evaluates nested AND and OR", %{tags: tags} do
      query = {:and, {:or, "tag1", "tag2"}, "tag3"}
      assert {:ok, result} = Query.eval(query, tags)
      # tag1 or tag2: [1,2,3,4,5,6,7]
      # tag3: [1,3,5,7,9]
      # intersection: [1,3,5,7]
      assert Enum.sort(result) == [1, 3, 5, 7]
    end

    test "evaluates NOT a tag", %{tags: tags} do
      query = {:not, "tag1"}
      assert {:ok, result} = Query.eval(query, tags)
      assert Enum.sort(result) == [6, 7, 8, 9]
    end

    test "evaluates complex nested conditions", %{tags: tags} do
      # (tag1 AND tag2) OR tag3
      query = {:or, {:and, "tag1", "tag2"}, "tag3"}
      assert {:ok, result} = Query.eval(query, tags)
      # tag1 and tag2: [3,4,5]
      # tag3: [1,3,5,7,9]
      # union: [1,3,4,5,7,9]
      assert Enum.sort(result) == [1, 3, 4, 5, 7, 9]
    end

    test "evaluates nested NOT conditions", %{tags: tags} do
      # tag1 AND NOT(tag2 AND tag3)
      query = {:and, "tag1", {:not, {:and, "tag2", "tag3"}}}
      assert {:ok, result} = Query.eval(query, tags)
      # tag2 and tag3: [3,5,7]
      # tag1: [1,2,3,4,5]
      # tag1 - (tag2 and tag3): [1,2,4]
      assert Enum.sort(result) == [1, 2, 4]
    end

    test "evaluates deeply nested conditions", %{tags: tags} do
      # (tag1 AND tag2) OR (tag1 AND tag3)
      query = {:or, {:and, "tag1", "tag2"}, {:and, "tag1", "tag3"}}
      assert {:ok, result} = Query.eval(query, tags)
      # tag1 and tag2: [3,4,5]
      # tag1 and tag3: [1,3,5]
      # union: [1,3,4,5]
      assert Enum.sort(result) == [1, 3, 4, 5]
    end

    test "handles empty result sets", %{tags: tags} do
      {:ok, empty_bitmap} = RoaringBitset.new()
      tags_with_empty = [%Tag{name: "empty", bitmap_ref: empty_bitmap} | tags]

      query = {:and, "tag1", "empty"}
      assert {:ok, result} = Query.eval(query, tags_with_empty)
      assert result == []
    end
  end
end
