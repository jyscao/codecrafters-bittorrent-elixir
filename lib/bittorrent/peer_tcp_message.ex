defmodule Bittorrent.Peer.TcpMessage do

  def connect({{_a,_b,_c,_d} = ipv4, port}) do
    case :gen_tcp.connect(ipv4, port, [:binary, active: false]) do
      {:ok, socket} -> {:ok, socket}
      err           -> err
    end
  end

  def do_handshake(socket, info_hash, self_peer_id) do
    with :ok <- :gen_tcp.send(socket, mk_handshake_msg(info_hash, self_peer_id)),
      {:ok, resp} <- :gen_tcp.recv(socket, 0)
    do
      {:ok, resp}
    else
      err -> err
    end
  end

  defp mk_handshake_msg(info_hash, self_peer_id), do:
    <<19>> <> "BitTorrent protocol" <> <<0::64>> <> info_hash <> self_peer_id
end
