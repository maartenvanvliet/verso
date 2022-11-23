defmodule Verso do
  @moduledoc """
  Documentation for `Verso`.
  """

  defmacro __using__(_opts) do
    quote location: :keep do
      @before_compile Verso
      Module.register_attribute(__MODULE__, :rules, accumulate: true)

      import(unquote(__MODULE__))

      def run(conn, req) do
        req =
          rules()
          |> Enum.reduce(req, fn rule, req ->
            case rule do
              {:rewrite_host, host} ->
                url = %{req.url | host: host}
                %{req | url: url}

              {:set_header, name, value} ->
                %{req | headers: [{name, value}] ++ req.headers}
            end
          end)

        if function_exported?(__MODULE__, :call, 2) do
          apply(__MODULE__, :call, [conn, req])
        else
          req
        end
      end
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      @doc false
      def rules, do: @rules |> List.flatten() |> Enum.reverse()
    end
  end

  defmacro rewrite_host(name) do
    quote do
      @rules {:rewrite_host, unquote(name)}
    end
  end

  defmacro set_header(name, value) do
    quote do
      @rules {:set_header, unquote(name), unquote(value)}
    end
  end
end
