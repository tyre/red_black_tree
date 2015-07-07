# RedBlackTree

[![Hex.pm](https://img.shields.io/hexpm/v/red_black_tree.svg)](https://hex.pm/packages/red_black_tree) [![Travis](https://img.shields.io/travis/SenecaSystems/red_black_tree.svg)](https://travis-ci.org/SenecaSystems/red_black_tree)

Red-black tree implementation for Elixir.

## Install

Add the following to your mix.exs deps:

`{:red_black_tree, "~> 1.0"}`

## About

Provides an ordered key-value store with `O(log(N))` lookup, insert, and delete
performance and `O(1)` size performance.

Implements the [Dict](http://elixir-lang.org/docs/stable/elixir/Dict.html)
behavior, [Enumerable](http://elixir-lang.org/docs/stable/elixir/Enumerable.html)
protocol, and the [Collectable](http://elixir-lang.org/docs/stable/elixir/Collectable.html)
protocol.

### Comparison

By default, keys are compared using strict equality (see note below), allowing for polymorphic keys in the same tree:

```elixir
RedBlackTree.new()
|> RedBlackTree.insert(:a, 1)
|> RedBlackTree.insert({:compound, :key}, 2)
```

A custom comparator may be provided at initialization via the `:comparator`
option.

For example, let's say we want to store maps containing order information,
sorted by the revenue generated and unique by id. We'll use the
`RedBlackTree.compare_terms` function for comparisions since it takes care of
weird cases (see note below.)


```elixir
order_revenue = RedBlackTree.new([], comparator: fn (value1, value2) ->
  # If the ids are the same, they are the same
  if value1.id === value2.id do
    0
  else
    case RedBlackTree.compare_terms(value1.revenue, value2.revenue) do
      # If the revenues are the same but the ids are different, fall back to id comparison for ordering
      0 -> RedBlackTree.compare_terms(value1.id, value2.id)
      # otherwise return the comparison
      revenue_comparison -> revenue_comparison
    end
  end
end)

updated_tree = order_revenue
  |> RedBlackTree.insert(%{id: 3, revenue: 40}, 40)
  |> RedBlackTree.insert(%{id: 50, revenue: 10}, 10)
  |> RedBlackTree.insert(%{id: 1, revenue: 50}, 50)
  |> RedBlackTree.insert(%{id: 2, revenue: 40}, 40)
# => #RedBlackTree<[{%{id: 50, revenue: 10}, 10}, {%{id: 2, revenue: 40}, 40},
 {%{id: 3, revenue: 40}, 40}, {%{id: 1, revenue: 50}, 50}]>

# Notice how changing the revenue of order 2 bumps it all the way to the end,
# since its revenue now equals order 1 but it loses the tie-breaker

RedBlackTree.insert(updated_tree, %{id: 2, revenue: 50}, 50)
# #RedBlackTree<[{%{id: 50, revenue: 10}, 10}, {%{id: 2, revenue: 40}, 40},
 {%{id: 3, revenue: 40}, 40}, {%{id: 1, revenue: 50}, 50},
 {%{id: 2, revenue: 50}, 50}]>
```

**Note**

Due to the way Erlang, and therefore Elixir, implement comparisons for floats
and integers, it is possible for a two keys to be equal (`key == other_key`)
but not strictly equal (`key !== other_key`).

To guarantee consistent ordering, the default `:comparator` function must
fallback to hashing keys that exhibit this property on comparison. In these rare
cases, there will be a small performance penalty.

Example:

```elixir
tree = RedBlackTree.new([1 => :bubbles])

# Hashing necessary since 1 != 1.0 and 1 == 1.0
updated = RedBlackTree.insert(tree, 1.0, :walrus)

# No hashing necessary, no performance impact
RedBlackTree.insert(updated, 0.5, :frank)
|> RedBlackTree.insert(1.5, :suzie)
```
