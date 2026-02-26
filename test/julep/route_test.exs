defmodule Julep.RouteTest do
  use ExUnit.Case, async: true

  alias Julep.Route

  describe "new/2" do
    test "creates a route with initial path" do
      route = Route.new("/home")

      assert Route.current(route) == "/home"
      assert Route.params(route) == %{}
    end

    test "creates a route with initial path and params" do
      route = Route.new("/users", %{id: 42})

      assert Route.current(route) == "/users"
      assert Route.params(route) == %{id: 42}
    end
  end

  describe "push/3" do
    test "adds a new route to the stack" do
      route =
        Route.new("/home")
        |> Route.push("/settings")

      assert Route.current(route) == "/settings"
    end

    test "push with params" do
      route =
        Route.new("/home")
        |> Route.push("/users", %{id: 7})

      assert Route.current(route) == "/users"
      assert Route.params(route) == %{id: 7}
    end

    test "previous route params preserved in stack" do
      route =
        Route.new("/home", %{tab: "recent"})
        |> Route.push("/settings")
        |> Route.pop()

      assert Route.params(route) == %{tab: "recent"}
    end
  end

  describe "pop/1" do
    test "returns to previous route" do
      route =
        Route.new("/home")
        |> Route.push("/settings")
        |> Route.pop()

      assert Route.current(route) == "/home"
    end

    test "does not pop the last route" do
      route =
        Route.new("/home")
        |> Route.pop()

      assert Route.current(route) == "/home"
    end

    test "pops through multiple levels" do
      route =
        Route.new("/a")
        |> Route.push("/b")
        |> Route.push("/c")
        |> Route.pop()
        |> Route.pop()

      assert Route.current(route) == "/a"
    end
  end

  describe "can_go_back?/1" do
    test "false for single-entry stack" do
      route = Route.new("/home")

      refute Route.can_go_back?(route)
    end

    test "true when stack has multiple entries" do
      route =
        Route.new("/home")
        |> Route.push("/settings")

      assert Route.can_go_back?(route)
    end
  end

  describe "history/1" do
    test "returns paths in stack order (most recent first)" do
      route =
        Route.new("/a")
        |> Route.push("/b")
        |> Route.push("/c")

      assert Route.history(route) == ["/c", "/b", "/a"]
    end

    test "single entry history" do
      route = Route.new("/home")

      assert Route.history(route) == ["/home"]
    end
  end
end
