defmodule Mix.Tasks.Elastic.Parse do
  use Mix.Task

  @shortdoc "Parse query"
  def run([mapping_file, query]) do
    mapping = mapping_file
              |> File.read!()
              |> Poison.decode!()
              |> Map.get("mappings")
              |> Map.values()
              |> List.first()
    filter = Poison.decode!(query)
    {:ok, elastic_query} = Esjql.build_filters(mapping, filter)
    IO.puts(Poison.encode!(elastic_query))
  end
end
