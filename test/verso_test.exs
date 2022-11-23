defmodule VersoTest do
  use ExUnit.Case
  use Plug.Test

  setup do
    start_supervised!({Finch, name: FinchProxy})
    :ok
  end

  describe "function upstream" do
    test "proxies to example.net with buffer" do
      conn = conn(:post, "/", "") |> Plug.Conn.assign(:raw_body, "body")
      opts = Verso.Plug.init(upstream: &call/2, http_opts: {FinchProxy, []})
      conn = Verso.Plug.call(conn, opts)

      assert conn.resp_body =~ "Example Domain"
      assert_received {:req, request}
      assert request == %Verso.Request{url: "http://example.net", method: "POST", body: "body"}
    end
  end

  def call(_conn, req) do
    request = %Verso.Request{req | url: "http://example.net"}
    send(self(), {:req, request})
    request
  end

  defmodule Upstream do
    use Verso

    rewrite_host("example.net")
    set_header("x-foo", "bar")

    def call(_conn, req) do
      send(self(), {:req, req})
      req
    end
  end

  describe "module upstream" do
    test "proxies to example.net with buffer" do
      conn = conn(:post, "/", "") |> Plug.Conn.assign(:raw_body, "body")
      opts = Verso.Plug.init(upstream: Upstream, http_opts: {FinchProxy, []})
      conn = Verso.Plug.call(conn, opts)

      assert conn.resp_body =~ "Example Domain"
      assert_received {:req, request}

      assert request == %Verso.Request{
               body: "body",
               headers: [{"x-foo", "bar"}],
               method: "POST",
               url: %URI{
                 scheme: "http",
                 userinfo: nil,
                 host: "example.net",
                 port: 80,
                 path: "/",
                 query: nil,
                 fragment: nil
               }
             }
    end
  end
end
