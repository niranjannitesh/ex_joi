defmodule ExJoi do
  def validate() do
    schema = [username: [type: :string, required: true, min: 2, max: 3]]

    data = %{"age" => 10, "username" => "xadd"}

    validate(schema, data)
  end

  def validate(schema, data) do
    keys = Keyword.keys(schema)
    schema = Enum.into(schema, %{})

    data =
      data
      |> convert_keys_to_atom()
      |> filter_unknown_keys(keys)

    collect_errors(data, keys, schema)
  end

  defp collect_errors(data, keys, schema) do
    Enum.reduce(keys, [], fn key, acc ->
      opts = schema[key]
      val = data[key]

      cond do
        Keyword.has_key?(opts, :type) ->
          case validate_type(Keyword.get(opts, :type), key, val, opts) do
            {:error, message} -> [{:error, message} | acc]
            _ -> acc
          end
      end
    end)
  end

  def validate_type(:string, key, val, opts) do
    has_min = Keyword.get(opts, :min)
    has_max = Keyword.get(opts, :max)

    cond do
      not is_binary(val) ->
        {:error, "`#{key}` is not a valid string"}

      has_max !== nil && String.length(val) > has_max ->
        {:error, "`#{key}` length must be less than or equal to #{has_max} characters long"}

      has_min !== nil && String.length(val) < has_min ->
        {:error, "`#{key}` length must be at least #{has_min} characters long"}

      true ->
        {:ok, val}
    end
  end

  defp convert_keys_to_atom(data) do
    data
    |> Map.new(fn
      {k, v} when is_bitstring(k) -> {String.to_atom(k), v}
      {k, v} -> {k, v}
    end)
  end

  defp filter_unknown_keys(data, keys) do
    Enum.reject(data, fn {key, _val} -> key not in keys end) |> Enum.into(%{})
  end
end
