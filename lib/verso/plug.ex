defmodule Verso.Plug do
  def init(opts) do
    :ok = validate_upstream(opts[:upstream])
    opts
  end

  def call(conn, opts) do
    request = get_upstream(opts[:upstream], conn)

    {name, opts} = opts[:http_opts]

    {:ok, response} =
      Finch.build(request.method, request.url, request.headers, request.body)
      |> Finch.request(name, opts)

    response = handle_response(response, opts[:handle_response])

    resp_headers =
      response.headers
      |> normalize_headers

    conn
    |> Plug.Conn.prepend_resp_headers(resp_headers)
    |> Plug.Conn.resp(response.status, response.body)
    |> Plug.Conn.send_resp()
  end

  defp validate_upstream(nil) do
    raise ArgumentError, "missing :upstream option"
  end

  defp validate_upstream(fun) when is_function(fun, 2) do
    :ok
  end

  defp validate_upstream(module) when is_atom(module) do
    :ok
  end

  defp handle_response(response, nil) do
    response
  end

  defp handle_response(response, fun) when is_function(fun, 2) do
    fun.(response)
  end

  defp normalize_headers(headers) do
    headers
    |> downcase_headers
    |> remove_hop_by_hop_headers
  end

  defp downcase_headers(headers) do
    headers
    |> Enum.map(fn {header, value} -> {String.downcase(header), value} end)
  end

  defp remove_hop_by_hop_headers(headers) do
    hop_by_hop_headers = [
      "te",
      "transfer-encoding",
      "trailer",
      "connection",
      "keep-alive",
      "proxy-authenticate",
      "proxy-authorization",
      "upgrade"
    ]

    Enum.reject(headers, fn {header, _} -> Enum.member?(hop_by_hop_headers, header) end)
  end

  defp build_request(conn) do
    body = do_read_body(conn)

    url = Plug.Conn.request_url(conn) |> URI.new!()
    %Verso.Request{method: conn.method, body: body, url: url, headers: conn.req_headers}
  end

  defp get_upstream(upstream, conn) when is_function(upstream) do
    request = build_request(conn)
    upstream.(conn, request)
  end

  defp get_upstream(upstream, conn) when is_atom(upstream) do
    request = build_request(conn)
    upstream.run(conn, request)
  end

  defp do_read_body(%{method: "GET"}), do: nil
  defp do_read_body(%{method: "OPTIONS"}), do: nil
  defp do_read_body(%{assigns: %{raw_body: raw_body}}), do: raw_body
end
