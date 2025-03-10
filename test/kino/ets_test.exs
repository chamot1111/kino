defmodule Kino.ETSTest do
  use ExUnit.Case, async: true

  describe "new/1" do
    test "raises an error when private table is given" do
      tid = :ets.new(:users, [:set, :private])

      assert_raise ArgumentError,
                   "the given table must be either public or protected, but a private one was given",
                   fn ->
                     Kino.ETS.new(tid)
                   end
    end

    test "raises an error when non-existent table is given" do
      tid = :ets.new(:users, [:set, :private])
      :ets.delete(tid)

      assert_raise ArgumentError,
                   "the given table identifier #{inspect(tid)} does not refer to an existing ETS table",
                   fn ->
                     Kino.ETS.new(tid)
                   end
    end
  end

  describe "connecting" do
    test "connect reply contains empty columns definition if there are no records" do
      tid = :ets.new(:users, [:set, :public])

      widget = Kino.ETS.new(tid)

      send(widget.pid, {:connect, self()})

      assert_receive {:connect_reply, %{columns: [], features: [:refetch, :pagination]}}
    end

    test "connect reply contains columns definition if there are some records" do
      tid = :ets.new(:users, [:set, :public])
      :ets.insert(tid, {1, "Terry Jeffords"})

      widget = Kino.ETS.new(tid)

      send(widget.pid, {:connect, self()})

      assert_receive {:connect_reply,
                      %{
                        columns: [%{key: 0, label: "0"}, %{key: 1, label: "1"}],
                        features: [:refetch, :pagination]
                      }}
    end
  end

  describe "querying rows" do
    setup do
      tid = :ets.new(:users, [:ordered_set, :public])

      :ets.insert(tid, {1, "Jake Peralta"})
      :ets.insert(tid, {2, "Terry Jeffords"})
      :ets.insert(tid, {3, "Amy Santiago"})

      {:ok, tid: tid}
    end

    test "replies with records and total rows", %{tid: tid} do
      widget = Kino.ETS.new(tid)
      connect_self(widget)

      spec = %{
        offset: 0,
        limit: 10,
        order_by: nil,
        order: :asc
      }

      send(widget.pid, {:get_rows, self(), spec})

      assert_receive {:rows,
                      %{
                        rows: [
                          %{id: _, fields: %{0 => "1", 1 => ~s/"Jake Peralta"/}},
                          %{id: _, fields: %{0 => "2", 1 => ~s/"Terry Jeffords"/}},
                          %{id: _, fields: %{0 => "3", 1 => ~s/"Amy Santiago"/}}
                        ],
                        total_rows: 3,
                        columns: [_, _]
                      }}
    end

    test "supports offset and limit", %{tid: tid} do
      widget = Kino.ETS.new(tid)
      connect_self(widget)

      spec = %{
        offset: 1,
        limit: 1,
        order_by: 0,
        order: :asc
      }

      send(widget.pid, {:get_rows, self(), spec})

      assert_receive {:rows,
                      %{
                        rows: [
                          %{id: _, fields: %{0 => "2", 1 => ~s/"Terry Jeffords"/}}
                        ],
                        total_rows: 3,
                        columns: [_, _]
                      }}
    end

    test "determines enough columns to accommodate longest record", %{tid: tid} do
      :ets.insert(tid, {4, "Sherlock Holmes", 100})
      :ets.insert(tid, {5, "John Watson", 150, :doctor})
      :ets.insert(tid, {6})

      widget = Kino.ETS.new(tid)
      connect_self(widget)

      spec = %{
        offset: 0,
        limit: 10,
        order_by: nil,
        order: :asc
      }

      send(widget.pid, {:get_rows, self(), spec})

      assert_receive {:rows,
                      %{
                        columns: [_, _, _, _]
                      }}
    end
  end

  defp connect_self(widget) do
    send(widget.pid, {:connect, self()})
    assert_receive {:connect_reply, %{}}
  end
end
