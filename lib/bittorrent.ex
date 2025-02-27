defmodule Bittorrent.CLI do
  import Shorthand
  alias Bittorrent.{Metainfo, Peer, Download}

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
        m(tracker_url, file_length, piece_length, piece_hashes) = Metainfo.extract_from_file(torrent_file)
        IO.puts("Tracker URL: #{tracker_url}")
        IO.puts("Length: #{file_length}")
        IO.puts("Info Hash: #{Metainfo.compute_info_hash(torrent_file)}")
        IO.puts("Piece Length: #{piece_length}")
        IO.puts("Piece Hashes:\n#{Enum.join(piece_hashes, "\n")}")

      ["peers", torrent_file] ->
        Peer.get_all_using_file(torrent_file)
        |> Stream.map(fn {{a,b,c,d}, port} -> "#{a}.#{b}.#{c}.#{d}:#{port}" end)
        |> Enum.join("\n")
        |> IO.puts()

      ["handshake", torrent_file, peer_addr_str] ->
        {:ok, peer_id} = Peer.shake_hand_and_get_peer_id(torrent_file, convert_addr_str(peer_addr_str))
        IO.puts("Peer ID: #{peer_id}")

      ["download_piece", "-o", output_location, torrent_file, pidx] ->
        Download.download_piece(torrent_file, String.to_integer(pidx), output_location)

      ["download", "-o", output_location, torrent_file] ->
        Download.download_all(torrent_file, output_location)

      ["magnet_parse", magnet_link] ->
        params = MagnetLink.parse(magnet_link)
        IO.puts("Tracker URL: #{params[:tr]}")
        IO.puts("Info Hash: #{params[:xt]}")

      [command | args] ->
        IO.puts("Unknown command: '#{command}' with arguments '#{args}'")
        System.halt(1)

      [] ->
        IO.puts("Usage: your_bittorrent.sh <command> <args>")
        System.halt(1)
    end
  end

  defp convert_addr_str(addr_str) do
    [ipv4_str, port_str] = String.split(addr_str, ":", parts: 2)
    {
      String.split(ipv4_str, ".", parts: 4) |> Enum.map(&(String.to_integer(&1))) |> List.to_tuple(),
      String.to_integer(port_str)
    }
  end
end
