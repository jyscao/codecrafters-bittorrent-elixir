defmodule Bittorrent.CLI do
    def main(argv) do
        case argv do
            ["decode" | [encoded_str | _]] ->
                decoded_str = Bencode.decode(encoded_str)
                IO.puts(Jason.encode!(decoded_str))
            [command | _] ->
                IO.puts("Unknown command: #{command}")
                System.halt(1)
            [] ->
                IO.puts("Usage: your_bittorrent.sh <command> <args>")
                System.halt(1)
        end
    end
end

defmodule Bencode do
    def decode(encoded_value) when is_binary(encoded_value) do
        binary_data = :binary.bin_to_list(encoded_value)

        colon_idx  = Enum.find_index(binary_data, &(&1===?:))
        is_integer = List.first(binary_data) === ?i and List.last(binary_data) === ?e

        cond do
            colon_idx ->
                Enum.slice(binary_data, colon_idx+1..-1//1) |> List.to_string()

            is_integer ->
                Enum.slice(binary_data, 1..-2//1) |> List.to_integer()

            true ->
                "Not a valid bencoded string"
        end
    end

    def decode(_), do: "Invalid encoded value: not binary"
end
