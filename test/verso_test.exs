defmodule VersoTest do
  use ExUnit.Case
  use Plug.Test

  setup do
    start_supervised!({Finch, name: FinchProxy})
    bypass = Bypass.open()
    {:ok, bypass: bypass}
  end

  describe "function upstream" do
    test "proxies to example.net with buffer", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/", fn conn ->
        assert {"x-test", "test"} in conn.req_headers

        Plug.Conn.resp(
          conn,
          429,
          ~s<test>
        )
      end)

      conn =
        conn(:post, "/", "")
        |> Plug.Conn.assign(:raw_body, "body")
        |> Plug.Conn.put_req_header("x-test", "test")

      opts = Verso.Plug.init(upstream: &call(&1, &2, bypass), http_opts: {FinchProxy, []})
      conn = Verso.Plug.call(conn, opts)

      assert conn.resp_body =~ "test"
      assert_received {:req, request}

      assert request == %Verso.Request{
               url: endpoint_url(bypass.port),
               method: "POST",
               headers: [{"x-test", "test"}],
               body: "body"
             }
    end
  end

  def call(_conn, req, bypass) do
    request = %Verso.Request{req | url: endpoint_url(bypass.port)}
    send(self(), {:req, request})
    request
  end

  defmodule Upstream do
    use Verso

    set_host("example.net")
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

  defp endpoint_url(port), do: "http://localhost:#{port}/"
end
