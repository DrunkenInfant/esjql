defmodule Esjql.Utils do
  def reduce_results(results) do
    Enum.reduce(results, {:ok, []}, fn item, res -> case {res, item} do
      {{:ok, res}, {:ok, item}} -> {:ok, [item | res]}
      {{:error, errors}, {:error, error}} -> {:error, [error | errors]}
      {_, {:error, error}} -> {:error, [error]}
      {res, _} -> res
    end end)
  end
end
