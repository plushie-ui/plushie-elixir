defmodule Plushie.ConnectTest do
  use ExUnit.Case, async: false

  describe "resolve_token/1" do
    test "explicit token wins over environment" do
      with_env("PLUSHIE_TOKEN", "from-env", fn ->
        assert Plushie.Connect.resolve_token(token: "from-opt") == "from-opt"
      end)
    end

    test "nil explicit token disables environment fallback" do
      with_env("PLUSHIE_TOKEN", "from-env", fn ->
        assert Plushie.Connect.resolve_token(token: nil) == nil
      end)
    end

    test "environment token is used when no token option is passed" do
      with_env("PLUSHIE_TOKEN", "from-env", fn ->
        assert Plushie.Connect.resolve_token([]) == "from-env"
      end)
    end
  end

  defp with_env(name, value, fun) do
    original = System.get_env(name)
    System.put_env(name, value)

    try do
      fun.()
    after
      if original do
        System.put_env(name, original)
      else
        System.delete_env(name)
      end
    end
  end
end
