defmodule Bittorrent.CLI do
  def main(argv) do
    case argv do
      ["decode", input | _] ->
        decoded_data = cond do
          String.ends_with?(input, ".torrent")
            -> Bencode.decode_file(input)
          true
            -> Bencode.decode(input)
        end
        Jason.encode!(decoded_data) |> IO.puts()

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
