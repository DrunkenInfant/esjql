defmodule Esjql.Aggregation do
  @doc """
  Parse aggregations from elastic response

  ## Examples
  iex> Esjql.Aggregation.build(%{"properties" => %{
  ...>   "person" => %{"type" => "nested", "properties" => %{
  ...>     "name" => %{"type" => "keyword"},
  ...>     "age" => %{"type" => "integer"}
  ...>   }},
  ...>   "title" => %{"type" => "keyword"}
  ...> }}, ["person.name", "person.age", "title"], 10)
  {:ok, %{aggs: %{
    "person" => %{
      nested: %{path: "person"},
      aggs: %{
        "person.name" => %{terms: %{field: "person.name", size: 10}},
        "person.age" => %{terms: %{field: "person.age", size: 10}}
      }
    },
    "title" => %{terms: %{field: "title", size: 10}}
  }}}

  """
  def build(%{"properties" => mapping}, terms, size) do
    result = terms
             |> Enum.map(&build_aggregation(mapping, String.split(&1, "."), [], size))
             |> Esjql.Utils.reduce_results()

    case result do
      {:ok, aggs} -> {:ok, aggs |> Enum.reduce(%{}, &merge_aggregations/2) |> (&Map.put(%{}, :aggs, &1)).()}
      err -> err
    end
  end

  @doc """
  Parse aggregations from elastic response

  ## Examples
      iex> Esjql.Aggregation.parse(%{"aggregations" => %{"age" => %{
      ...>   "buckets" => [
      ...>     %{"key" => 1, "doc_count" => 1},
      ...>     %{"key" => 2, "doc_count" => 2}
      ...>   ],
      ...>   "sum_other_doc_count" => 0
      ...> }}})
      [
        %{property: "age", values: [%{value: 1, count: 1}, %{value: 2, count: 2}], has_more: false}
      ]

  """
  def parse(result) do
    result
    |> Map.get("aggregations", [])
    |> Enum.flat_map(&parse_aggregation/1)
  end

  defp build_aggregation(mapping, [term | _] = path, parents, size) do
    case Map.get(mapping, term) do
      nil -> {:error, "Unknown mapping for '#{join_path(term, parents)}'"}
      type -> build_aggregation_typed(type, path, parents, size)
    end
  end

  defp build_aggregation_typed(%{"type" => "nested", "properties" => mapping}, [term | nested], parents, size) do
    name = join_path(term, parents)
    case build_aggregation(mapping, nested, [term | parents], size) do
      {:ok, nested_aggs} -> {:ok, Map.put( %{}, name, %{nested: %{path: name}, aggs: nested_aggs})}
      err -> err
    end
  end

  defp build_aggregation_typed(%{"type" => "object", "dynamic" => true} = mapping, [term | nested ], parents, size) do
    nested_mapping = Map.get(mapping, "properties", %{})
    case Map.get(nested_mapping, List.first(nested)) do
      nil -> build_aggregation_typed(%{"type" => "keyword"}, [Enum.join(nested, ".")], [term | parents], size)
      type -> build_aggregation_typed(type, nested, [term | parents], size)
    end
  end

  defp build_aggregation_typed(%{"type" => "object", "properties" => mapping}, [term | nested ], parents, size) do
    build_aggregation(mapping, nested, [term | parents], size)
  end

  defp build_aggregation_typed(%{"type" => _}, [term], parents, size) do
    name = join_path(term, parents)
    {:ok, Map.put(%{}, name, %{terms: %{field: name, size: size}})}
  end

  defp parse_aggregation({term, %{"buckets" => buckets, "sum_other_doc_count" => others}}), do: [%{
    property: term,
    has_more: others > 0,
    values: Enum.map(buckets, &parse_bucket/1)
  }]

  defp parse_aggregation({_term, nested}) do
    nested
    |> Map.drop(["doc_count"])
    |> Enum.flat_map(&parse_aggregation/1)
  end

  defp parse_bucket(%{"key" => key, "doc_count" => count}) do
    %{value: key, count: count}
  end

  defp join_path(term, parents),
    do: [term | parents] |> Enum.reverse() |> Enum.join(".")

  defp merge_aggregations(%{} = a1, %{} = a2),
    do: Map.merge(a1, a2, fn _k, n1, n2 -> merge_aggregations(n1, n2) end)

  defp merge_aggregations(a1, _a2), do: a1
end
