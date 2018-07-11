defmodule RedBlackTree do
  @moduledoc """
  Red-black trees are key-value stores.
  While not guaranteed to be perfectly balanced, guarantees `O(log(N))` lookup,
  insert, and delete performance and `O(1)` size performance.

  The RedBlackTree module contains an eponymous struct and various useful
  functions.

  Nodes know their depth (automatically updated on insert/delete)
  """
  alias RedBlackTree.Node

  defstruct root: nil, size: 0, comparator: &__MODULE__.compare_terms/2

  @key_hash_bucket 4294967296

  @behaviour Access

  # Inline key hashing
  @compile {:inline, hash_term: 1, fallback_term_hash: 1}

  @doc """
  Create a new RedBlackTree.
  Can either be initialized with no values, with values, or with values and
  options.
  The passed in values can either be a list of `{key, value}` or a list of
  elements. In the latter case, the elements will be their own keys.

  ## Options
    - `:comparator`
      function that takes in two keys and returns:
        + `0` if the keys should be considered equal
        + `-1` if the first argument should be considered "less than" the second
        + `1` if the second argument should be considered "greater than" the
          first
      By default, uses `RedBlackTree.compare_terms/2`, which compares the terms
      according to Erlang's term precedence, using `:erlang.phash2/1` comparison
      as a fallback for cases when `term1 == term2` but `term1 !== term2`.

  ## Examples

      iex> RedBlackTree.new
      #RedBlackTree<[]>
      iex> RedBlackTree.new([{:kind, :walrus}, {:name, :frank}, {:bubbles, 7}])
      #RedBlackTree<[bubbles: 7, kind: :walrus, name: :frank]>
      iex> RedBlackTree.new([1,2,3])
      #RedBlackTree<[{1, 1}, {2, 2}, {3, 3}]>

  Let's try out a comparator function that reverses the default ordering:

      iex> RedBlackTree.new([{:kind, :walrus}, {:name, :frank}, {:bubbles, 7}],
      ...>   comparator: fn (key1, key2) ->
      ...>     RedBlackTree.compare_terms(key1, key2) * -1
      ...>   end
      ...> )
      #RedBlackTree<[name: :frank, kind: :walrus, bubbles: 7]>
  """
  def new() do
    %RedBlackTree{}
  end

  def new(values, opts \\ [])
  def new(values, opts) do
    do_new(%RedBlackTree{
      comparator: :proplists.get_value(:comparator, opts, &compare_terms/2)
      }, values)
  end

  defp do_new(tree, []) do
    tree
  end

  # Allow initialization with key/value tuples
  defp do_new(tree, [{key, value}|tail]) do
    do_new(RedBlackTree.insert(tree, key, value), tail)
  end

  # Allow initialization with individual values, in which case they will be both
  # the key and the value
  defp do_new(tree, [key|tail]) do
    do_new(RedBlackTree.insert(tree, key, key), tail)
  end

  @doc """
  Inserts the given key and value into the provided tree.
  Returns the updated tree.
  """
  def insert(%RedBlackTree{root: nil}=tree, key, value) do
    %RedBlackTree{tree | root: Node.new(key, value), size: 1}
  end

  def insert(%RedBlackTree{root: root, size: size, comparator: comparator}=tree, key, value) do
    {nodes_added, new_root} = do_insert(root, key, value, 1, comparator)
    %RedBlackTree{
      tree |
      root: make_node_black(new_root),
      size: size + nodes_added
    }
  end

  # Deletes the given key and value from the provided tree.
  # Returns the updated tree.
  def delete(%RedBlackTree{root: root, size: size, comparator: comparator}=tree, key) do
    {nodes_removed, new_root} = do_delete(root, key, comparator)
    %RedBlackTree{
      tree |
      root: new_root,
      size: size - nodes_removed
    }
  end

  # Returns the `value` associated with `key`.
  # Returns `nil` if the key does not exist.
  def get(%RedBlackTree{root: root, comparator: comparator}, key) do
    do_get(root, key, comparator)
  end

  def size(%RedBlackTree{size: size}) do
    size
  end

  def put(tree, key, value) do
    insert(tree, key, value)
  end

  def reduce(tree, acc, fun) do
    RedBlackTree.to_list(tree)
    |> Enumerable.List.reduce(acc, fun)
  end

  ## Access behaviour functions

  def fetch(tree, key) do
    if has_key?(tree, key) do
      {:ok, get(tree, key)}
    else
      :error
    end
  end

  def get(tree, key, default) do
    case fetch(tree, key) do
      {:ok, val} -> val
      :error -> default
    end
  end

  def get_and_update(tree, key, fun) do
    {get, update} = fun.(RedBlackTree.get(tree, key))
    {get, RedBlackTree.insert(tree, key, update)}
  end

  def pop(tree, key) do
    value = RedBlackTree.get(tree, key, :error)
    new_tree = RedBlackTree.delete(tree, key)
    {value, new_tree}
  end

  ## Tree behaviour functions

  def insert(tree, key) do
    insert(tree, key, nil)
  end

  def member?(tree, key) do
    has_key?(tree, key)
  end

  defp do_get(nil, _key, _comparator) do
    nil
  end

  defp do_get(%Node{key: node_key, left: left, right: right, value: value}, get_key, comparator) do
    case comparator.(get_key, node_key) do
      0 -> value
      -1 -> do_get(left, get_key, comparator)
      1 -> do_get(right, get_key, comparator)
    end
  end

  def has_key?(%RedBlackTree{root: root, comparator: comparator}, key) do
    do_has_key?(root, key, comparator)
  end

  defp do_has_key?(nil, _key, _comparator) do
    false
  end

  defp do_has_key?(%Node{key: node_key, left: left, right: right}, search_key, comparator) do
    case comparator.(search_key, node_key) do
      0 -> true
      -1 -> do_has_key?(left, search_key, comparator)
      1 -> do_has_key?(right, search_key, comparator)
    end
  end

  @doc """
  For each node, calls the provided function passing in (node, acc)
  Optionally takes an order as the first argument which can be one of
  `:in_order`, `:pre_order`, or `:post_order`.

  Defaults to `:in_order` if no order is given.
  """
  def reduce_nodes(%RedBlackTree{}=tree, acc, fun) do
    reduce_nodes(:in_order, tree, acc, fun)
  end

  def reduce_nodes(_order, %RedBlackTree{root: nil}, acc, _fun) do
    acc
  end

  def reduce_nodes(order, %RedBlackTree{root: root}, acc, fun) do
    do_reduce_nodes(order, root, acc, fun)
  end

  @doc """
  Balances the supplied tree to adhere to the two rules of Red-Black trees:

  1. Every red node must have two black child nodes (and therefore it must have a black parent).
  2. Every path from a given node to any of its descendant NIL nodes contains the same number of black nodes.

  """
  def balance(%RedBlackTree{root: root}=tree) do
    %RedBlackTree{tree | root: do_balance(root)}
  end

  @doc """
  Converts a `%RedBlackTree{}` to a list.

  Options available:
  - `:order` - available options are `:in_order`, `:pre_order`, or `:post_order`
    Defaults to `:in_order` if no order is given.
  """
  def to_list(%RedBlackTree{}=tree, opts \\ []) do
    opts
    |> Keyword.get(:order, :in_order)
    |> reduce_nodes(tree, [],
      fn (node, members) ->
        [{node.key, node.value} | members]
      end)
    |> Enum.reverse
  end

  ## Helpers

  defp make_node_black(%Node{}=node) do
    Node.color(node, :black)
  end

  @doc """
  Compares two terms.
  Returns `0` if they are strictly equal (`===`).
  Returns `-1` if they the first argument is less than the second.
  Returns `1` if they the first argument is greater than the second.

  Falls back to `:erlang.phash2/1` in cases where
  `term1 == term2 && term1 !== term2`. In case of key collisions, falls back
  again to `:erlang.phash/1`.
  """
  def compare_terms(term1, term2) do
    cond do
      term1 === term2 -> 0
      term1 < term2 -> -1
      term1 > term2 -> 1
      term1 == term2 ->
        case compare_terms(hash_term(term1), hash_term(term2)) do
          0 -> compare_terms(fallback_term_hash(term1), fallback_term_hash(term2))
          hash_comparison_result -> hash_comparison_result
        end
    end
  end

  # ¡This is only used as a tiebreaker!
  # For cases when `insert_key !== node_key` but `insert_key == node_key` (e.g.
  # `1` and `1.0`,) hash the keys to provide consistent ordering.
  defp hash_term(term) do
    :erlang.phash2(term, @key_hash_bucket)
  end

  # In the case that `hash_term(term1) == hash_term(term2)` we can fall back
  # again to the slower phash function distributed over @key_hash_bucket
  # integers.
  # If these two collide, go home.
  defp fallback_term_hash(term) do
    :erlang.phash(term, @key_hash_bucket)
  end

  ### Operations

  #### Insert

  defp do_insert(nil, insert_key, insert_value, depth, _comparator) do
    {
      1,
      %Node{
        Node.new(insert_key, insert_value, depth) |
        color: :red
      }
    }
  end

  defp do_insert(%Node{key: node_key}=node, insert_key, insert_value, depth, comparator) do
    case comparator.(insert_key, node_key) do
      0 -> {0, %Node{node | value: insert_value}}
      -1 -> do_insert_left(node, insert_key, insert_value, depth, comparator)
      1 -> do_insert_right(node, insert_key, insert_value, depth, comparator)
    end
  end

  defp do_insert_left(%Node{left: left}=node, insert_key, insert_value, depth, comparator) do
    {nodes_added, new_left} = do_insert(left, insert_key, insert_value, depth + 1, comparator)
    {nodes_added, %Node{node | left: do_balance(new_left)}}
  end

  defp do_insert_right(%Node{right: right}=node, insert_key, insert_value, depth, comparator) do
    {nodes_added, new_right} = do_insert(right, insert_key, insert_value, depth + 1, comparator)
    {nodes_added, %Node{node | right: do_balance(new_right)}}
  end

  #### Delete

  # If we reach a leaf and the key never matched, do nothing
  defp do_delete(nil, _key, _comparator) do
    {0, nil}
  end

  defp do_delete(%Node{key: node_key}=node, delete_key, comparator) do
    case comparator.(delete_key, node_key) do
      0 -> do_delete_node(node)
      -1 -> do_delete_left(node, delete_key, comparator)
      1 -> do_delete_right(node, delete_key, comparator)
    end
  end

  defp do_delete_node(%Node{left: left, right: right}) do
    cond do
      # If both the right and left are nil, the new tree is nil. For example,
      # deleting A in the following tree results in B having no left
      #
      #        B
      #       / \
      #      A   C
      #
      (left === nil && right === nil) -> {1, nil}

      # If left is nil and there is a right, promote the right. For example,
      # deleting C in the following tree results in B's right becoming D
      #
      #        B
      #       / \
      #      A   C
      #           \
      #            D
      #
      (left === nil && right) -> {1, %Node{right | depth: right.depth - 1}}
      # If there is only a left promote it. For example,
      # deleting B in the following tree results in C's left becoming A
      #
      #        C
      #       / \
      #      B   D
      #     /
      #    A
      #
      (left && right === nil) -> {1, %Node{left | depth: left.depth - 1}}
      # If there are both left and right nodes, recursively promote the left-most
      # nodes. For example, deleting E below results in the following:
      #
      #        G      =>         G
      #       / \               / \
      #      E   H    =>       C   H
      #     / \               / \
      #    C   F      =>     B   D
      #   / \               /     \
      #  A   D        =>   A       F
      #   \
      #    B
      #
      #
      true ->
        {
          1,
          do_balance(%Node{
            left |
            depth: left.depth - 1,
            left: do_balance(promote(left)),
            right: right
          })
        }
    end
  end

  defp do_delete_left(%Node{left: left}=node, delete_key, comparator) do
    {nodes_removed, new_left} = do_delete(left, delete_key, comparator)
    {
      nodes_removed,
      %Node{
        node |
        left: do_balance(new_left)
      }
    }
  end

  defp do_delete_right(%Node{right: right}=node, delete_key, comparator) do
    {nodes_removed, new_right} = do_delete(right, delete_key, comparator)
    {
      nodes_removed,
      %Node{
        node |
        right: do_balance(new_right)
      }
    }
  end

  defp promote(nil) do
    nil
  end

  defp promote(%Node{left: nil, right: nil, depth: depth}=node) do
    %Node{ node | color: :red, depth: depth - 1 }
  end

  defp promote(%Node{left: left, right: nil, depth: depth}) do
    %Node{ left | color: :red, depth: depth - 1}
  end

  defp promote(%Node{left: nil, right: right, depth: depth}) do
    %Node{ right | color: :red, depth: depth - 1}
  end

  defp promote(%Node{left: left, right: right, depth: depth}) do
    balance(%Node{
      left |
      depth: depth - 1,
      left: do_balance(promote(left)),
      right: right
    })
  end

  #### Balance

  # If we have a tree that looks like this:
  #              B (Black)
  #             /         \
  #            A          D (Red)
  #                      /       \
  #                     C         F (Red)
  #                              /       \
  #                             E         G
  #
  #
  # Rotate to balance and look like this:
  #
  #                   D (Red)
  #                 /         \
  #          B (Black)        F (Black)
  #         /        \       /         \
  #        A          C     E           G
  #
  #
  defp do_balance(
    %Node{
      color: :black,
      left: a_node,
      right: %Node{
        color: :red,
        left: c_node,
        right: %Node{
          color: :red,
          left: e_node,
          right: g_node
        }=f_node
      }=d_node
    }=b_node) do

    balanced_tree(a_node, b_node, c_node, d_node, e_node, f_node, g_node)
  end

  # If we have a tree that looks like this:
  #
  #         B (Black)
  #        /         \
  #       A       F (Red)
  #              /       \
  #           D (Red)     G
  #          /       \
  #         C         E
  #
  # Rotate to balance like so:
  #
  #                D (Red)
  #               /       \
  #        B (Black)       F (Black)
  #       /         \     /         \
  #      A           C   E           G
  #
  #
  #
  defp do_balance(
    %Node{
      color: :black,
      left: a_node,
      right: %Node{
        color: :red,
        left: %Node{
          color: :red,
          left: c_node,
          right: e_node
        }=d_node,
        right: g_node
      }=f_node
    }=b_node) do

    balanced_tree(a_node, b_node, c_node, d_node, e_node, f_node, g_node)
  end

  # If we have a tree that looks like this:
  #
  #
  #                 F (Black)
  #                /         \
  #               D (Red)     G
  #              /       \
  #           B (Red)     E
  #          /       \
  #         A          C
  #
  #
  # Rebalance to look like so:
  #
  #               D (Red)
  #              /       \
  #      B (Black)        F (Black)
  #     /         \      /         \
  #    A           C    E           G
  #
  defp do_balance(%Node{
      color: :black,
      left: %Node{
        color: :red,
        left: %Node{
          color: :red,
          left: a_node,
          right: c_node
        }=b_node,
        right: e_node
      }=d_node,
      right: g_node
    }=f_node) do

    balanced_tree(a_node, b_node, c_node, d_node, e_node, f_node, g_node)
  end

  # If we have a tree that looks like this:
  #
  #               F (Black)
  #              /         \
  #          B (Red)        G
  #         /       \
  #        A         D (Red)
  #                 /       \
  #                C         E
  #
  # Rebalance to look like this:
  #
  #            D (Red)
  #           /       \
  #     B (Black)      F (Black)
  #    /         \    /         \
  #   A           C  E           G
  #
  defp do_balance(%Node{
      color: :black,
      left: %Node{
        color: :red,
        left: a_node,
        right: %Node{
          color: :red,
          left: c_node,
          right: e_node
        }=d_node
      }=b_node,
      right: g_node
    }=f_node) do

    balanced_tree(a_node, b_node, c_node, d_node, e_node, f_node, g_node)
  end


  defp do_balance(node) do
    node
  end

  defp balanced_tree(a_node, b_node, c_node, d_node, e_node, f_node, g_node) do
    min_depth = min_depth([a_node, b_node, c_node, d_node, e_node, f_node, g_node])
    %Node {
      d_node |
      color: :red,
      depth: min_depth,
      left: %Node{b_node | color: :black, depth: min_depth + 1,
        left: %Node{a_node | depth: min_depth + 2},
        right: %Node{c_node | depth: min_depth + 2}},
      right: %Node{f_node | color: :black, depth: min_depth + 1,
        left: %Node{e_node | depth: min_depth + 2},
        right: %Node{g_node | depth: min_depth + 2},}
    }
  end

  defp min_depth(list_of_nodes) do
    Enum.reduce(list_of_nodes, -1, fn (node, acc) ->
      if acc == -1 || node.depth < acc do
        node.depth
      else
        acc
      end
    end)
  end

  defp do_reduce_nodes(_order, nil, acc, _fun) do
    acc
  end

  # self, left, right
  defp do_reduce_nodes(:pre_order, %Node{left: left, right: right}=node, acc, fun) do
    acc_after_self = fun.(node, acc)
    acc_after_left = do_reduce_nodes(:pre_order, left, acc_after_self, fun)
    do_reduce_nodes(:pre_order, right, acc_after_left, fun)
  end

  # left, self, right
  defp do_reduce_nodes(:in_order, %Node{left: left, right: right}=node, acc, fun) do
    acc_after_left = do_reduce_nodes(:in_order, left, acc, fun)
    acc_after_self = fun.(node, acc_after_left)
    do_reduce_nodes(:in_order, right, acc_after_self, fun)
  end

  # left, right, self
  defp do_reduce_nodes(:post_order, %Node{left: left, right: right}=node, acc, fun) do
    acc_after_left = do_reduce_nodes(:post_order, left, acc, fun)
    acc_after_right = do_reduce_nodes(:post_order, right, acc_after_left, fun)
    fun.(node, acc_after_right)
  end

end

defimpl Enumerable, for: RedBlackTree do
  def count(%RedBlackTree{size: size}), do: size
  def member?(%RedBlackTree{}=tree, key), do: RedBlackTree.has_key?(tree, key)
  def reduce(tree, acc, fun), do: RedBlackTree.reduce(tree, acc, fun)
end

defimpl Collectable, for: RedBlackTree do
  def into(original) do
    {original, fn
      tree, {:cont, {key, value}} -> RedBlackTree.insert(tree, key, value)
      tree, :done -> tree
      _, :halt -> :ok
    end}
  end
end


# We want our own inspect so that it will hide the implementation-specific
# fields. Otherwise users may try to play with them directly.
defimpl Inspect, for: RedBlackTree do
  import Inspect.Algebra

  def inspect(tree, opts) do
    concat ["#RedBlackTree<", Inspect.List.inspect(RedBlackTree.to_list(tree), opts), ">"]
  end
end
