defmodule Bittorrent.CLI do
    def main(argv) do
        case argv do
            ["decode" | [encoded_str | _]] ->
                decoded_str = Bencode.decode(encoded_str)
                IO.puts(Jason.encode!(decoded_str))

            ["info" | torrent_file] ->
                {:ok, encoded_str} = File.read(torrent_file)
                metainfo = Metainfo.get_all(encoded_str)
                IO.puts("Tracker URL: #{metainfo.tracker_url}")
                IO.puts("Length: #{metainfo.file_length}")
                IO.puts("Info Hash: #{metainfo.info_hash}")
                IO.puts("Piece Length: #{metainfo.piece_length}")
                IO.puts("Piece Hashes:\n#{metainfo.piece_hashes}")

            ["peers" | torrent_file] ->
                {:ok, encoded_str} = File.read(torrent_file)
                peers = Peers.get(encoded_str)
                IO.puts(peers)

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
