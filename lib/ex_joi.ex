defmodule ExJoi do
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
    Enum.reduce(keys, %{}, fn key, acc ->
      opts = schema[key]
      val = data[key]

      cond do
        Keyword.has_key?(opts, :type) ->
          case validate_type(Keyword.get(opts, :type), key, val, opts) do
            {:ok, _} ->
              acc

            error ->
              cond do
                (is_list(error) || is_map(error)) and Enum.empty?(error) -> acc
                true -> Map.put(acc, key, error)
              end
          end
      end
    end)
  end

  def validate_type(:string, key, val, opts) do
    has_min = Keyword.get(opts, :min)
    has_max = Keyword.get(opts, :max)
    has_required = Keyword.get(opts, :required)

    case {has_required, val} do
      {false, nil} ->
        {:ok, val}

      {true, nil} ->
        {:error, "`#{key}` is required"}

      _ ->
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
  end

  def validate_type(:number, key, val, opts) do
    has_min = Keyword.get(opts, :min)
    has_max = Keyword.get(opts, :max)
    has_required = Keyword.get(opts, :required)

    case {has_required, val} do
      {false, nil} ->
        {:ok, val}

      {true, nil} ->
        {:error, "`#{key}` is required"}

      _ ->
        cond do
          not is_number(val) ->
            {:error, "`#{key}` is not a valid number"}

          has_max !== nil && val > has_max ->
            {:error, "`#{key}` must be less than or equal to #{has_max}"}

          has_min !== nil && val < has_min ->
            {:error, "`#{key}` must be greater than or equal to #{has_min}"}

          true ->
            {:ok, val}
        end
    end
  end

  def validate_type(:map, key, val, opts) do
    has_required = Keyword.get(opts, :required)
    has_properties = Keyword.get(opts, :properties)

    case {has_required, val} do
      {false, nil} ->
        {:ok, val}

      {true, nil} ->
        {:error, "`#{key}` is required"}

      _ ->
        cond do
          not is_map(val) ->
            {:error, "`#{key}` is not a valid object"}

          has_properties !== nil ->
            validate(has_properties, val)

          true ->
            {:ok, val}
        end
    end
  end

  def validate_type(type, key, val, opts) do
    case Application.fetch_env(:ex_joi, type) do
      {:ok, fnc} -> fnc.(type, key, val, opts)
      :error -> raise "could not find validator for type `:#{type}`"
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
