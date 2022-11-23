defmodule Verso.Request do
  defstruct [:url, :method, :body, headers: []]
end
