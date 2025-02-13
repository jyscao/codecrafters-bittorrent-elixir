defmodule Handshake do
    @self_peer_id :crypto.hash(:sha, "jyscao")

    def get_peer_id(encoded_str, peer_addr) do
        info_hash_raw = Metainfo.get_info_hash_raw(encoded_str)

        make_connection(peer_addr)
        |> do_handshake(info_hash_raw)
        |> extract_peer_id(info_hash_raw)
    end

    defp make_connection(peer_addr) do
        [ipv4_str, port_str] = String.split(peer_addr, ":", parts: 2)
        {ipv4, port} = {
            String.split(ipv4_str, ".", parts: 4) |> Enum.map(&(String.to_integer(&1))) |> List.to_tuple(),
            String.to_integer(port_str)
        }

        opts = [:binary, active: false]
        case :gen_tcp.connect(ipv4, port, opts) do
            {:ok, socket}    -> socket
            {:error, reason} -> reason
        end
    end

    defp do_handshake(socket, info_hash_raw) do
        with :ok <- :gen_tcp.send(socket, make_msg(info_hash_raw)), 
            {:ok, resp} <- :gen_tcp.recv(socket, 0)
        do
            resp
        else
            err -> {:error, err}
        end
    end

    defp make_msg(info_hash_raw), do:
        <<19>> <> "BitTorrent protocol" <> <<0::64>> <> info_hash_raw <> @self_peer_id

    defp extract_peer_id(<<header_int::224, info_hash_int::160, peer_id_int::160>>, computed_info_hash) do
        with <<19>> <> "BitTorrent protocol" <> <<0::64>> = :binary.encode_unsigned(header_int),
            ^computed_info_hash = :binary.encode_unsigned(info_hash_int)
        do
            :binary.encode_unsigned(peer_id_int) |> Base.encode16(case: :lower)
        end
    end
end
