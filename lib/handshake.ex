defmodule Handshake do
    def get_peer_id(encoded_str, peer_addr) do
        info_hash_raw = Metainfo.get_info_hash_raw(encoded_str)

        socket = connect(peer_addr)
        {:ok, resp} = do_handshake(socket, info_hash_raw)

        extract_peer_id(resp, info_hash_raw)
    end

    defp connect(peer_addr) do
        [ipv4_str, port_str] = String.split(peer_addr, ":", parts: 2)
        {ipv4, port} = {
            String.split(ipv4_str, ".", parts: 4) |> Enum.map(&(String.to_integer(&1))) |> List.to_tuple(),
            String.to_integer(port_str)
        }

        opts = [:binary, active: false]
        case :gen_tcp.connect(ipv4, port, opts) do
            {:ok, socket} -> socket
            {:error, reason} -> reason
        end
    end

    defp do_handshake(socket, info_hash_raw) do
        msg = construct_handshake_message(info_hash_raw)
        case :gen_tcp.send(socket, msg) do
            :ok              -> :gen_tcp.recv(socket, 0)
            {:error, reason} -> {:error, reason}
        end
    end

    defp construct_handshake_message(info_hash_raw) do
        msg_header    = <<19>> <> "BitTorrent protocol" <> <<0::64>>
        self_peer_id  = :crypto.hash(:sha, "jyscao")
        msg_header <> info_hash_raw <> self_peer_id
    end

    defp extract_peer_id(<<header::224, info_hash::160, peer_id::160>>, info_hash_raw) do
        with ^header <- :binary.decode_unsigned(<<19>> <> "BitTorrent protocol" <> <<0::64>>),
            ^info_hash <- :binary.decode_unsigned(info_hash_raw)
        do
            :binary.encode_unsigned(peer_id) |> Base.encode16(case: :lower)
        else
            _err -> {:error, "cannot validate and/or parse client response"}
        end
    end
end
