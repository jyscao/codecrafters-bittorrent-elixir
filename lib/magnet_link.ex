defmodule MagnetLink do

  def parse("magnet:?" <> params) do
    URI.query_decoder(params)
    |> Enum.map(fn {key, val} ->
      case key do
        "xt" -> "urn:btih:" <> info_hash = val; {:xt, info_hash}
        "tr" -> {:tr, val}
        _    -> nil
      end
    end)
    |> Enum.filter(&(&1))
  end

  def parse(_link), do: raise("invalid magnet link")
end
