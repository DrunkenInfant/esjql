defmodule Esjql.Properties do
  @moduledoc """
  Documentation for Esjql.Properties.
  """

  @doc """
  Flatten index mappings to list of properties

  ## Examples
      iex> Esjql.Properties.flatten(%{"properties" => %{
      ...>   "person" => %{
      ...>     "type" => "object",
      ...>     "dynamic" => true,
      ...>     "properties" => %{"name" => %{"type" => "keyword"}, "age" => %{ "type" => "integer" }}
      ...>   },
      ...>   "toughness" => %{"type" => "integer"}
      ...> }})
      [
          %{name: "person.*", type: "dynamic"},
          %{name: "person.age", type: "integer"},
          %{name: "person.name", type: "keyword"},
          %{name: "toughness", type: "integer"}
      ]

  """
  def flatten(%{"properties" => mapping}) do
    mapping
    |> Enum.flat_map(fn {prop, desc} -> case desc do
      %{"index" => false} -> []
      %{"dynamic" => true} -> [%{name: "#{prop}.*", type: "dynamic"} | flatten(desc)
                                                             |> Enum.map(&Map.update!(&1, :name, fn n -> "#{prop}.#{n}" end))]
      %{"type" => type} when type in ["object", "nested"] -> flatten(desc)
                                                             |> Enum.map(&Map.update!(&1, :name, fn n -> "#{prop}.#{n}" end))
      %{"type" => type} -> [%{name: prop, type: type}]
    end end)
  end

  def flatten(%{}) do
    []
  end

  @doc """
  Flatten index mappings to list of properties

  ## Examples
      iex> Esjql.Properties.unflatten(%{"properties" => %{
      ...>   "person" => %{
      ...>     "type" => "object",
      ...>     "dynamic" => true,
      ...>     "properties" => %{"name" => %{"type" => "keyword"}, "age" => %{ "type" => "integer" }}
      ...>   },
      ...>   "toughness" => %{"type" => "integer"}
      ...> }})
      [
        %{
          name: "person",
          type: "object",
          dynamic: true,
          children:
            [
              %{name: "age", type: "integer"},
              %{name: "name", type: "keyword"},
            ]
        },
        %{name: "toughness", type: "integer"}
      ]

  """
  def unflatten(%{"properties" => mapping}) do
    mapping
    |> Enum.flat_map(fn {prop, desc} -> case desc do
      %{"index" => false} ->
        []
      %{"type" => type} when type in ["object", "nested"] ->
        [%{name: prop, type: type, dynamic: Map.get(desc, "dynamic", true), children: unflatten(desc)}]
      %{"type" => type} ->
        [%{name: prop, type: type}]
    end end)
  end

  def unflatten(%{}), do: []
end
