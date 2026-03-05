defmodule Julep.Features do
  @moduledoc "Feature flag resolution for iced widget features."

  @all_iced_features [:image, :svg, :canvas, :markdown, :highlighter, :sysinfo, :qr_code]

  @spec iced_features() :: :all | [atom()]
  def iced_features do
    Application.get_env(:julep, :iced_features, :all)
  end

  @spec iced_feature_enabled?(feature :: atom()) :: boolean()
  def iced_feature_enabled?(feature) do
    case iced_features() do
      :all -> true
      list -> feature in list
    end
  end

  @spec all_iced_features() :: [atom()]
  def all_iced_features, do: @all_iced_features

  @spec cargo_feature_name(feature :: atom()) :: String.t()
  def cargo_feature_name(feature) do
    "widget-#{feature |> Atom.to_string() |> String.replace("_", "-")}"
  end
end
