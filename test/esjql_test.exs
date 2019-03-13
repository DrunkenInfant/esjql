defmodule EsjqlTest do
  use ExUnit.Case
  doctest Esjql

  test "build empty" do
    assert Esjql.build_filters(%{"properties" => %{}}, %{}) ==
      {:ok, %{query: %{bool: %{filter: []}}}}
  end

  test "build term" do
    mapping = %{"properties" => %{"name" => %{ "type" => "keyword" }}}
    filter = %{"name" => "foo"}
    assert Esjql.build_filters(mapping, filter) ==
      {:ok, %{query: %{bool: %{filter: [%{term: %{"name" => "foo"}}]}}}}
  end

  test "build terms" do
    mapping = %{"properties" => %{"name" => %{ "type" => "keyword" }}}
    filter = %{"name" => ["foo", "bar"]}
    assert Esjql.build_filters(mapping, filter) ==
      {:ok, %{query: %{bool: %{filter: [%{terms: %{"name" => ["foo", "bar"]}}]}}}}
  end

  test "build prefix" do
    mapping = %{"properties" => %{"name" => %{ "type" => "keyword" }}}
    filter = %{"name" => "^foo"}
    assert Esjql.build_filters(mapping, filter) ==
      {:ok, %{query: %{bool: %{filter: [%{prefix: %{"name" => "foo"}}]}}}}
  end

  test "build integer" do
    mapping = %{"properties" => %{"age" => %{ "type" => "integer" }}}
    filter = %{"age" => "1"}
    assert Esjql.build_filters(mapping, filter) ==
      {:ok, %{query: %{bool: %{filter: [%{term: %{"age" => 1}}]}}}}
  end

  test "build float" do
    mapping = %{"properties" => %{"age" => %{ "type" => "float" }}}
    filter = %{"age" => "1.1"}
    assert Esjql.build_filters(mapping, filter) ==
      {:ok, %{query: %{bool: %{filter: [%{term: %{"age" => 1.1}}]}}}}
  end

  test "build greater than" do
    mapping = %{"properties" => %{"age" => %{ "type" => "integer" }}}
    filter = %{"age" => ">1"}
    assert Esjql.build_filters(mapping, filter) ==
      {:ok, %{query: %{bool: %{filter: [%{range: %{"age" => %{gt: 1}}}]}}}}
  end

  test "build greater than or equal to" do
    mapping = %{"properties" => %{"age" => %{ "type" => "integer" }}}
    filter = %{"age" => ">=1"}
    assert Esjql.build_filters(mapping, filter) ==
      {:ok, %{query: %{bool: %{filter: [%{range: %{"age" => %{gte: 1}}}]}}}}
  end

  test "build less than" do
    mapping = %{"properties" => %{"age" => %{ "type" => "integer" }}}
    filter = %{"age" => "<1"}
    assert Esjql.build_filters(mapping, filter) ==
      {:ok, %{query: %{bool: %{filter: [%{range: %{"age" => %{lt: 1}}}]}}}}
  end

  test "build less than or equal to" do
    mapping = %{"properties" => %{"age" => %{ "type" => "integer" }}}
    filter = %{"age" => "<=1"}
    assert Esjql.build_filters(mapping, filter) ==
      {:ok, %{query: %{bool: %{filter: [%{range: %{"age" => %{lte: 1}}}]}}}}
  end

  test "build multiple numeric" do
    mapping = %{"properties" => %{"age" => %{ "type" => "integer" }}}
    filter = %{"age" => ["<=1", ">=1", "<1", ">1"]}
    assert Esjql.build_filters(mapping, filter) ==
      {:ok, %{query: %{bool: %{filter: [%{range: %{"age" => %{gte: 1, gt: 1, lt: 1, lte: 1}}}]}}}}
  end

  test "build date single" do
    mapping = %{"properties" => %{"timestamp" => %{ "type" => "date" }}}
    filter = %{"timestamp" => "1"}
    assert Esjql.build_filters(mapping, filter) ==
      {:ok, %{query: %{bool: %{filter: [%{term: %{"timestamp" => 1}}]}}}}
  end

  test "build date numeric range" do
    mapping = %{"properties" => %{"timestamp" => %{ "type" => "date" }}}
    filter = %{"timestamp" => [">1", "<2"]}
    assert Esjql.build_filters(mapping, filter) ==
      {:ok, %{query: %{bool: %{filter: [%{range: %{"timestamp" => %{gt: 1, lt: 2}}}]}}}}
  end

  test "build date symbolic range" do
    mapping = %{"properties" => %{"timestamp" => %{ "type" => "date" }}}
    filter = %{"timestamp" => [">now-1d", "<now/1d"]}
    assert Esjql.build_filters(mapping, filter) ==
      {:ok, %{query: %{bool: %{filter: [%{range: %{"timestamp" => %{gt: "now-1d", lt: "now/1d"}}}]}}}}
  end

  test "build object term" do
    mapping = %{"properties" => %{"person" => %{"type" => "object", "properties" => %{"name" => %{ "type" => "keyword" }}}}}
    filter = %{"person.name" => "foo"}
    assert Esjql.build_filters(mapping, filter) ==
      {:ok, %{query: %{bool: %{filter: [%{term: %{"person.name" => "foo"}}]}}}}
  end

  test "build nested term" do
    mapping = %{"properties" => %{"person" => %{"type" => "nested", "properties" => %{"name" => %{"type" => "keyword"}}}}}
    filter = %{"person.name" => ["foo", "bar"]}
    assert Esjql.build_filters(mapping, filter) ==
      {:ok, %{query: %{bool: %{filter: [%{nested: %{path: "person", query: %{bool: %{filter: [%{terms: %{"person.name" => ["foo", "bar"]}}]}}}}]}}}}
  end

  test "build multiple nested" do
    mapping = %{"properties" => %{"person" => %{"type" => "nested", "properties" => %{"name" => %{"type" => "keyword"}, "age" => %{"type" => "integer"}}}}}
    filter = %{"person.name" => "foo", "person.age" => "10"}
    assert Esjql.build_filters(mapping, filter) ==
      {:ok, %{query: %{bool: %{filter: [%{nested: %{path: "person", query: %{bool: %{filter: [
        %{term: %{"person.name" => "foo"}},
        %{term: %{"person.age" => 10}},
      ]}}}}]}}}}
  end

  test "unknown property error" do
    mapping = %{"properties" => %{}}
    filter = %{"age" => "1"}
    assert Esjql.build_filters(mapping, filter) ==
      {:error, ["Unknown mapping for 'age'"]}
  end

  test "unknown object property error" do
    mapping = %{"properties" => %{"person" => %{"type" => "object", "properties" => %{"name" => %{"type" => "keyword"}}}}}
    filter = %{"person.age" => "1"}
    assert Esjql.build_filters(mapping, filter) ==
      {:error, ["Unknown mapping for 'person.age'"]}
  end

  test "unknown nested property error" do
    mapping = %{"properties" => %{"person" => %{"type" => "nested", "properties" => %{"name" => %{"type" => "keyword"}}}}}
    filter = %{"person.age" => "1"}
    assert Esjql.build_filters(mapping, filter) ==
      {:error, ["Unknown mapping for 'person.age'"]}
  end

  test "flatten simple mapping" do
    mapping = %{"properties" => %{"age" => %{ "type" => "integer" }}}
    assert Esjql.flatten_properties(mapping) ==
      [%{name: "age", type: "integer"}]
  end

  test "flatten multiple mappings" do
    mapping = %{"properties" => %{"name" => %{"type" => "keyword"}, "age" => %{ "type" => "integer" }}}
    assert Esjql.flatten_properties(mapping) ==
      [%{name: "age", type: "integer"}, %{name: "name", type: "keyword"}]
  end

  test "flatten nested mappings" do
    mapping = %{"properties" => %{"person" => %{"type" => "nested", "properties" => %{"name" => %{"type" => "keyword"}, "age" => %{ "type" => "integer" }}}}}
    assert Esjql.flatten_properties(mapping) ==
      [%{name: "person.age", type: "integer"}, %{name: "person.name", type: "keyword"}]
  end

  test "flatten object mappings" do
    mapping = %{"properties" => %{"person" => %{"type" => "object", "properties" => %{"name" => %{"type" => "keyword"}, "age" => %{ "type" => "integer" }}}}}
    assert Esjql.flatten_properties(mapping) ==
      [%{name: "person.age", type: "integer"}, %{name: "person.name", type: "keyword"}]
  end
end
