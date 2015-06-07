# RedBlackTree

Red-black tree implementation for Elixir.

## Install

Add the following to your mix.exs deps:

`{:red_black_tree, "~> 1.0"}`

## About

Provides an ordered key-value store with `O(log(N))` lookup, insert, and delete
performance and `O(1)` size performance.

Keys are compared using strict equality (`===`), allowning for polymorphic
keys in the same tree:

```elixir
RedBlackTree.new()
|> RedBlackTree.insert(:a, 1)
|> RedBlackTree.insert({:compound, :key}, 2)
```

Implements the [Dict](http://elixir-lang.org/docs/stable/elixir/Dict.html)
behavior, [Enumerable](http://elixir-lang.org/docs/stable/elixir/Enumerable.html)
protocol, and the [Collectable](http://elixir-lang.org/docs/stable/elixir/Collectable.html)
protocol.


**Note**

Due to the way Erlang, and therefore Elixir, implement comparisons for floats
and integers, it is possible for a two keys to be equal (`key == other_key`)
but not strictl equal (`key !== other_key`). To guarantee consistent ordering,
we must fallback to hashing keys that exhibit this property on comparison. In
these rare cases, there will be a small performance penalty.

Example:

```elixir
tree = RedBlackTree.new([1 => :bubbles])

# Hashing necessary since 1 != 1.0 and 1 == 1.0
updated = RedBlackTree.insert(tree, 1.0, :walrus)

# No hashing necessary, no performance impact
RedBlackTree.insert(updated, 0.5, :frank)
|> RedBlackTree.insert(1.5, :suzie)
```
