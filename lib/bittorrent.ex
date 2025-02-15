defmodule Bittorrent.CLI do
  def main(argv) do
    case argv do
      ["decode" | [encoded_str | _]] ->
        decoded_str = Bencode.decode(encoded_str)
        IO.puts(Jason.encode!(decoded_str))

      ["info", torrent_file] ->
        {:ok, encoded_str} = File.read(torrent_file)
        metainfo = Metainfo.get_all(encoded_str)
        IO.puts("Tracker URL: #{metainfo.tracker_url}")
        IO.puts("Length: #{metainfo.file_length}")
        IO.puts("Info Hash: #{metainfo.info_hash}")
        IO.puts("Piece Length: #{metainfo.piece_length}")
        IO.puts("Piece Hashes:\n#{Enum.join(metainfo.piece_hashes, "\n")}")

      ["peers", torrent_file] ->
        {:ok, encoded_str} = File.read(torrent_file)
        peers = Peers.get(encoded_str)
        IO.puts(Enum.join(peers, "\n"))

      ["handshake", torrent_file, peer_addr] ->
        {:ok, encoded_str} = File.read(torrent_file)
        peer_id = Handshake.get_peer_socket(peer_addr) |> Handshake.get_peer_id(encoded_str)
        IO.puts("Peer ID: #{peer_id}")

      ["download_piece", "-o", output_location, torrent_file, pidx] ->
        {:ok, encoded_str} = File.read(torrent_file)
        :ok = Message.download_piece!(encoded_str, String.to_integer(pidx), output_location)

      ["download", "-o", output_location, torrent_file] ->
        {:ok, encoded_str} = File.read(torrent_file)
        :ok = Message.download_file(encoded_str, output_location)

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
