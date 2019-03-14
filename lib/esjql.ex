defmodule Esjql do
  @moduledoc """
  Documentation for Esjql.
  """

  @doc """
  Build qwery

  ## Examples
  # Empty query
      iex> Esjql.build_filters(%{"properties" => %{}}, %{})
      {:ok, %{query: %{bool: %{filter: []}}}}

  # Simple term query
      iex> Esjql.build_filters(%{"properties" => %{"foo" => %{"type" => "keyword"}}}, %{"foo" => "bar"})
      {:ok, %{query: %{bool: %{filter: [%{term: %{"foo" => "bar"}}]}}}}

  # Simple terms query
      iex> Esjql.build_filters(%{"properties" => %{"foo" => %{"type" => "keyword"}}}, %{"foo" => ["bar", "baz"]})
      {:ok, %{query: %{bool: %{filter: [%{terms: %{"foo" => ["bar","baz"]}}]}}}}

  """
  def build_filters(%{"properties" => mapping}, filters) do
    parsed = parse_filters(filters)
    with {:ok, es_filter} <- Enum.map(parsed, &build_filter(mapping, &1)) |> Esjql.Utils.reduce_results() do
      {:ok, %{query: %{bool: %{
        filter: Enum.concat(es_filter)
      }}}}
    else
      {:error, errors} -> {:error, Enum.concat(errors)}
      err -> err
    end
  end

  @doc """
  Flatten index mappings to list of properties

  ## Examples
      iex> Esjql.flatten_properties(%{"properties" => %{
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
  def flatten_properties(%{"properties" => mapping}) do
    mapping
    |> Enum.flat_map(fn {prop, desc} -> case desc do
      %{"index" => false} -> []
      %{"dynamic" => true} -> [%{name: "#{prop}.*", type: "dynamic"} | flatten_properties(desc)
                                                             |> Enum.map(&Map.update!(&1, :name, fn n -> "#{prop}.#{n}" end))]
      %{"type" => type} when type in ["object", "nested"] -> flatten_properties(desc)
                                                             |> Enum.map(&Map.update!(&1, :name, fn n -> "#{prop}.#{n}" end))
      %{"type" => type} -> [%{name: prop, type: type}]
    end end)
  end

  def flatten_properties(%{}) do
    []
  end

  defp parse_filters(filters) do
    filters
    |> Enum.map(&parse_filter/1)
    |> group_filters()
  end

  defp parse_filter({key, value}) do
    %{
      path: String.split(key, "."),
      key: key,
      value: value
    }
  end

  defp group_filters(filters, parent_keys \\ []) do
    filters
    |> Enum.group_by(fn (%{path: [prop | _]}) -> prop end)
    |> Enum.map(&merge_filters(&1, parent_keys))
  end

  defp merge_filters({key, filters}, parent_keys) do
    values = filters
             |> Enum.map(fn %{path: path, value: value} -> case path do
               [_key] -> case value do
                 value when not is_list(value) -> [value]
                 values -> values
               end
               _ -> []
            end end)
            |> Enum.concat
    %{
      value: values,
      key: key,
      prop: Enum.reverse([key | parent_keys]) |> Enum.join("."),
      nested: filters
              |> Enum.filter(fn %{path: path} -> case path do
                [] -> false
                [_] -> false
                _ -> true
              end end)
              |> Enum.map(&Map.update!(&1, :path, fn p -> Enum.drop(p, 1) end))
              |> group_filters([key | parent_keys])
    }
  end

  defp build_filter(mappings, %{key: key} = filter) do
    build_filter_typed(Map.get(mappings, key, %{}), filter)
  end

  defp build_filter_typed(%{"type" => "nested", "properties" => mapping}, %{prop: prop, nested: nested}) do
    case Enum.map(nested, &build_filter(mapping, &1)) |> Esjql.Utils.reduce_results() do
      {:ok, nested_filter} -> {:ok, [%{nested: %{
        path: prop,
        query: %{bool: %{filter: Enum.concat(nested_filter)}}
      }}]}
      {:error, errors} -> {:error, Enum.concat(errors)}
      err -> err
    end
  end

  defp build_filter_typed(%{"type" => "object", "properties" => mapping}, %{nested: nested}) do
    case Enum.map(nested, &build_filter(mapping, &1)) |> Esjql.Utils.reduce_results() do
      {:ok, filters} -> {:ok, Enum.concat(filters)}
      {:error, errors} -> {:error, Enum.concat(errors)}
      err -> err
    end
  end

  defp build_filter_typed(%{"type" => "keyword"} = type, %{value: [value]} = filter),
    do: build_filter_typed(type, Map.put(filter, :value, value))

  defp build_filter_typed(%{"type" => "keyword"}, %{prop: prop, value: value}) when is_list(value),
    do: {:ok, [terms(prop, value)]}

  defp build_filter_typed(%{"type" => "keyword"}, %{prop: prop, value: "^" <> value}),
    do: {:ok, [prefix(prop, value)]}

  defp build_filter_typed(%{"type" => "keyword"}, %{prop: prop, value: value}),
    do: {:ok, [term(prop, value)]}

  defp build_filter_typed(%{"type" => num_type}, %{prop: prop, value: values}) when num_type in ["long", "integer", "short", "byte", "double", "float", "half_float", "scaled_float"] do
    with {:ok, ops} <- values |> Enum.map(&parse_numeric(&1, num_type)) |> Esjql.Utils.reduce_results() do
      case Enum.into(ops, %{}) do
        %{eq: val} -> {:ok, [term(prop, val)]}
        ops -> {:ok, [range(prop, ops)]}
      end
    else
      {:error, errors} -> [{:error, errors}]
      err -> [{:error, [err]}]
    end
  end

  defp build_filter_typed(%{"type" => "date"}, %{prop: prop, value: values}) do
    with {:ok, ops} <- values |> Enum.map(&parse_date(&1)) |> Esjql.Utils.reduce_results() do
      case Enum.into(ops, %{}) do
        %{eq: val} -> {:ok, [term(prop, val)]}
        ops -> {:ok, [range(prop, ops)]}
      end
    else
      {:error, errors} -> [{:error, errors}]
      err -> [{:error, [err]}]
    end
  end

  defp build_filter_typed(_mapping, %{prop: prop}), do: {:error, ["Unknown mapping for '#{prop}'"]}

  defp parse_numeric(value, type) do
    {mod, num} = parse_compare_op(value)

    parsed = case type do
      int when int in ["long", "integer", "short", "byte"] -> Integer.parse(num)
      float when float in ["double", "float", "half_float", "scaled_float"] -> Float.parse(num)
    end

    case parsed do
      {val, ""} -> {:ok, {mod, val}}
      :error -> %{error: "#{value} not numeric"}
    end
  end

  defp parse_date(value) do
    {op, value} = parse_compare_op(value)
    case Integer.parse(value) do
      {num, ""} -> {:ok, {op, num}}
      _ -> {:ok, {op, value}}
    end
  end

  defp parse_compare_op(value) do
    case value do
      "<=" <> val -> {:lte, val}
      ">=" <> val -> {:gte, val}
      "<" <> val -> {:lt, val}
      ">" <> val -> {:gt, val}
      val -> {:eq, val}
    end
  end

  defp terms(prop, value), do: %{terms: %{prop => value}}
  defp term(prop, value), do: %{term: %{prop => value}}
  defp prefix(prop, value), do: %{prefix: %{prop => value}}
  defp range(prop, value), do: %{range: %{prop => value}}
end
