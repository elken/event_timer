defmodule EventTimer.IdType do
  @behaviour Ecto.Type

  def type, do: :string

  def cast(value) when is_binary(value), do: {:ok, value}
  def cast(value), do: {:ok, to_string(value)}

  def dump(value) when is_binary(value), do: {:ok, value}
  def dump(value), do: {:ok, to_string(value)}

  def load(value) when is_binary(value), do: {:ok, value}
  def load(_), do: :error

  def embed_as(_), do: :self

  def equal?(a, b), do: to_string(a) == to_string(b)
end
