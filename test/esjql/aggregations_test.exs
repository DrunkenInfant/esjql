defmodule EsjqlAggregationTest do
  use ExUnit.Case
  doctest Esjql.Aggregation

  test "build empty aggregation" do
    mapping = %{"properties" => %{"name" => %{"type" => "keyword"}}}
    properties = []
    assert Esjql.Aggregation.build(mapping, properties, 10) == {:ok, %{aggs: %{}}}
  end

  test "build simple term aggregation" do
    mapping = %{"properties" => %{"name" => %{"type" => "keyword"}}}
    properties = ["name"]
    assert Esjql.Aggregation.build(mapping, properties, 10) ==
      {:ok, %{aggs: %{"name" => %{terms: %{field: "name", size: 10}}}}}
  end

  test "build two term aggregations" do
    mapping = %{"properties" => %{"name" => %{"type" => "keyword"}, "age" => %{"type" => "integer"}}}
    properties = ["name", "age"]
    assert Esjql.Aggregation.build(mapping, properties, 10) ==
      {:ok, %{aggs: %{"name" => %{terms: %{field: "name", size: 10}}, "age" => %{terms: %{field: "age", size: 10}}}}}
  end

  test "build object term aggregation" do
    mapping = %{"properties" => %{"person" => %{"type" => "object", "properties" => %{"name" => %{"type" => "keyword"}}}}}
    properties = ["person.name"]
    assert Esjql.Aggregation.build(mapping, properties, 10) ==
      {:ok, %{aggs: %{"person.name" => %{terms: %{field: "person.name", size: 10}}}}}
  end

  test "build dynamic object term aggregation" do
    mapping = %{"properties" => %{"person" => %{"type" => "object", "dynamic" => true}}}
    properties = ["person.name"]
    assert Esjql.Aggregation.build(mapping, properties, 10) ==
      {:ok, %{aggs: %{"person.name" => %{terms: %{field: "person.name", size: 10}}}}}
  end

  test "build partial dynamic object typed term aggregation" do
    mapping = %{"properties" => %{"person" => %{"type" => "object", "dynamic" => true, "properties" => %{"name" => %{"type" => "keyword"}}}}}
    properties = ["person.name"]
    assert Esjql.Aggregation.build(mapping, properties, 10) ==
      {:ok, %{aggs: %{"person.name" => %{terms: %{field: "person.name", size: 10}}}}}
  end

  test "build partial dynamic object untyped term aggregation" do
    mapping = %{"properties" => %{"person" => %{"type" => "object", "dynamic" => true, "properties" => %{"name" => %{"type" => "keyword"}}}}}
    properties = ["person.age"]
    assert Esjql.Aggregation.build(mapping, properties, 10) ==
      {:ok, %{aggs: %{"person.age" => %{terms: %{field: "person.age", size: 10}}}}}
  end

  test "build nested term aggregation" do
    mapping = %{"properties" => %{"person" => %{"type" => "nested", "properties" => %{"name" => %{"type" => "keyword"}}}}}
    properties = ["person.name"]
    assert Esjql.Aggregation.build(mapping, properties, 10) ==
      {:ok, %{aggs: %{"person" => %{nested: %{path: "person"}, aggs: %{"person.name" => %{terms: %{field: "person.name", size: 10}}}}}}}
  end

  test "build multiple nested term aggregations" do
    mapping = %{"properties" => %{"person" => %{"type" => "nested", "properties" => %{"name" => %{"type" => "keyword"}, "age" => %{"type" => "integer"}}}}}
    properties = ["person.name", "person.age"]
    assert Esjql.Aggregation.build(mapping, properties, 10) ==
      {:ok, %{aggs: %{"person" => %{nested: %{path: "person"}, aggs: %{"person.name" => %{terms: %{field: "person.name", size: 10}}, "person.age" => %{terms: %{field: "person.age", size: 10}}}}}}}
  end

  test "build aggregation with missing type" do
    mapping = %{"properties" => %{"name" => %{"type" => "keyword"}}}
    properties = ["age"]
    assert Esjql.Aggregation.build(mapping, properties, 10) ==
      {:error, ["Unknown mapping for 'age'"]}
  end

  test "build aggregation with missing object type" do
    mapping = %{"properties" => %{"person" => %{"type" => "object", "properties" => %{"name" => %{"type" => "keyword"}}}}}
    properties = ["person.age"]
    assert Esjql.Aggregation.build(mapping, properties, 10) ==
      {:error, ["Unknown mapping for 'person.age'"]}
  end

  test "parse one aggregation" do
    aggregations = %{"aggregations" => %{"age" => %{
      "buckets" => [
        %{"key" => 1, "doc_count" => 1},
        %{"key" => 2, "doc_count" => 2}
      ],
      "sum_other_doc_count" => 0
    }}}
    assert Esjql.Aggregation.parse(aggregations) ==
      [%{property: "age", values: [%{value: 1, count: 1}, %{value: 2, count: 2}], has_more: false}]
  end

  test "parse nested aggregation" do
    aggregations = %{"aggregations" => %{"person" => %{
      "person.age" => %{
        "buckets" => [
          %{"key" => 1, "doc_count" => 1},
          %{"key" => 2, "doc_count" => 2}
        ],
        "sum_other_doc_count" => 0
      },
      "person.name" => %{
        "buckets" => [
          %{"key" => "foo", "doc_count" => 1},
          %{"key" => "bar", "doc_count" => 2}
        ],
        "sum_other_doc_count" => 0
      }
    }}}
    assert Esjql.Aggregation.parse(aggregations) ==
      [
        %{property: "person.age", values: [%{value: 1, count: 1}, %{value: 2, count: 2}], has_more: false},
        %{property: "person.name", values: [%{value: "foo", count: 1}, %{value: "bar", count: 2}], has_more: false}
      ]
  end
end
