defmodule Esjql.PropertiesTest do
  use ExUnit.Case
  doctest Esjql.Properties

  test "flatten simple mapping" do
    mapping = %{"properties" => %{"age" => %{ "type" => "integer" }}}
    assert Esjql.Properties.flatten(mapping) ==
      [%{name: "age", type: "integer"}]
  end

  test "flatten multiple mappings" do
    mapping = %{"properties" => %{"name" => %{"type" => "keyword"}, "age" => %{ "type" => "integer" }}}
    assert Esjql.Properties.flatten(mapping) ==
      [%{name: "age", type: "integer"}, %{name: "name", type: "keyword"}]
  end

  test "flatten nested mappings" do
    mapping = %{"properties" => %{"person" => %{"type" => "nested", "properties" => %{"name" => %{"type" => "keyword"}, "age" => %{ "type" => "integer" }}}}}
    assert Esjql.Properties.flatten(mapping) ==
      [%{name: "person.age", type: "integer"}, %{name: "person.name", type: "keyword"}]
  end

  test "flatten object mappings" do
    mapping = %{"properties" => %{"person" => %{"type" => "object", "properties" => %{"name" => %{"type" => "keyword"}, "age" => %{ "type" => "integer" }}}}}
    assert Esjql.Properties.flatten(mapping) ==
      [%{name: "person.age", type: "integer"}, %{name: "person.name", type: "keyword"}]
  end

  test "flatten dynamic object mapping" do
    mapping = %{"properties" => %{"person" => %{"type" => "object", "dynamic" => true, "properties" => %{"name" => %{"type" => "keyword"}, "age" => %{ "type" => "integer" }}}}}
    assert Esjql.Properties.flatten(mapping) ==
      [%{name: "person.*", type: "dynamic"}, %{name: "person.age", type: "integer"}, %{name: "person.name", type: "keyword"}]
  end

  test "flatten empty dynamic object mapping" do
    mapping = %{"properties" => %{"person" => %{"type" => "object", "dynamic" => true}}}
    assert Esjql.Properties.flatten(mapping) ==
      [%{name: "person.*", type: "dynamic"}]
  end

  test "flatten non-indexed property" do
    mapping = %{"properties" => %{"person" => %{"index" => false}}}
    assert Esjql.Properties.flatten(mapping) ==
      []
  end

  test "unflatten one simple property" do
    mapping = %{"properties" => %{"age" => %{ "type" => "integer" }}}
    assert Esjql.Properties.unflatten(mapping) ==
      [%{name: "age", type: "integer"}]
  end

  test "unflatten two simple properties" do
    mapping = %{"properties" => %{"name" => %{"type" => "keyword"}, "age" => %{ "type" => "integer" }}}
    assert Esjql.Properties.unflatten(mapping) ==
      [%{name: "age", type: "integer"}, %{name: "name", type: "keyword"}]
  end

  test "unflatten two nested properties" do
    mapping = %{"properties" => %{"person" => %{"type" => "nested", "properties" => %{
      "name" => %{"type" => "keyword"},
      "age" => %{ "type" => "integer" }
    }}}}
    assert Esjql.Properties.unflatten(mapping) ==
      [%{
        name: "person",
        type: "nested",
        dynamic: true,
        children: [%{name: "age", type: "integer"}, %{name: "name", type: "keyword"}]
      }]
  end

  test "unflatten two object properties" do
    mapping = %{"properties" => %{"person" => %{"type" => "object", "properties" => %{
      "name" => %{"type" => "keyword"},
      "age" => %{ "type" => "integer" }
    }}}}
    assert Esjql.Properties.unflatten(mapping) ==
      [%{
        name: "person",
        type: "object",
        dynamic: true,
        children: [%{name: "age", type: "integer"}, %{name: "name", type: "keyword"}]
      }]
  end

  test "unflatten pure dynamic nexted property" do
    mapping = %{"properties" => %{"person" => %{"type" => "nested"}}}
    assert Esjql.Properties.unflatten(mapping) ==
      [
        %{name: "person", type: "nested", dynamic: true, children: []}
      ]
  end

  test "unflatten ignore non-indexed property" do
    mapping = %{"properties" => %{"foo" => %{"type" => "binarey", "index" => false}}}
    assert Esjql.Properties.unflatten(mapping) == []
  end
end
