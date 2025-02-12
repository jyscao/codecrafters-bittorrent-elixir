defmodule Bittorrent.CLI do
    def main(argv) do
        case argv do
            ["decode" | [encoded_str | _]] ->
                decoded_str = Bencode.decode(encoded_str)
                IO.puts(Jason.encode!(decoded_str))

            ["info" | torrent_file ] ->
                {:ok, encoded_str} = File.read(torrent_file)

                %{"announce" => tracker_url, "info" => %{"length" => length}} = Bencode.decode(encoded_str)
                IO.puts("Tracker URL: #{tracker_url}")
                IO.puts("Length: #{length}")

                info_hash = Bencode.get_info_hash(encoded_str)
                IO.puts("Info Hash: #{info_hash}")

            [command | _] ->
                IO.puts("Unknown command: #{command}")
                System.halt(1)

            [] ->
                IO.puts("Usage: your_bittorrent.sh <command> <args>")
                System.halt(1)
        end
    end
end

# example - d8:announce35:http://tracker.example.com/announce4:infod6:lengthi12345e4:name10:sample.txt12:piece lengthi65536e6:pieces20:abcdefghij1234567890e8:url-list29:http://example.com/sample.txte
