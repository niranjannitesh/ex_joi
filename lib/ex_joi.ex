defmodule ExJoi do
  def validate(schema, data) do
    keys = Keyword.keys(schema)
    schema = Enum.into(schema, %{})

    data = convert_keys_to_atom(data)
    {data, errors} = collect_errors(data, keys, schema)

    case Enum.empty?(errors) do
      true -> {:ok, data}
      _ -> {:error, errors}
    end
  end

  defp collect_errors(data, keys, schema) do
    Enum.reduce(keys, {%{}, %{}}, fn key, {f_data, errors} ->
      opts = Map.get(schema, key)
      val = data[key]

      cond do
        is_list(opts) ->
          results = Enum.map(opts, fn x -> validate_type(Map.get(x, :type), key, val, x) end)

          only_type_errors =
            Enum.reduce(results, true, fn {err_t, _}, acc -> acc && err_t === :type_error end)

          case only_type_errors do
            true ->
              types = Enum.map(opts, fn x -> x.type end)

              {f_data,
               Map.put(errors, key, "`#{key}` must be one of [#{Enum.join(types, ", ")}]")}

            false ->
              case Enum.find(results, fn {t, _} -> t === :validation_error end) do
                {:validation_error, msg} -> {f_data, Map.put(errors, key, msg)}
                _ -> {Map.put(f_data, key, val), errors}
              end
          end

        Map.has_key?(opts, :type) ->
          case validate_type(Map.get(opts, :type), key, val, opts) do
            {:ok, _val} ->
              {Map.put(f_data, key, val), errors}

            {_, message} ->
              {f_data, Map.put(errors, key, message)}
          end
      end
    end)
  end

  def validate_type(:string, key, val, opts) do
    has_min = Map.get(opts, :min)
    has_max = Map.get(opts, :max)
    has_required = Map.get(opts, :required)

    case {has_required, val} do
      {false, nil} ->
        {:ok, val}

      {true, nil} ->
        {:validation_error, "`#{key}` is required"}

      _ ->
        cond do
          not is_binary(val) ->
            {:type_error, "`#{key}` is not a valid string"}

          has_max !== nil && String.length(val) > has_max ->
            {:validation_error,
             "`#{key}` length must be less than or equal to #{has_max} characters long"}

          has_min !== nil && String.length(val) < has_min ->
            {:validation_error, "`#{key}` length must be at least #{has_min} characters long"}

          true ->
            {:ok, val}
        end
    end
  end

  def validate_type(:number, key, val, opts) do
    has_min = Map.get(opts, :min)
    has_max = Map.get(opts, :max)
    has_required = Map.get(opts, :required)

    case {has_required, val} do
      {false, nil} ->
        {:ok, val}

      {true, nil} ->
        {:validation_error, "`#{key}` is required"}

      _ ->
        cond do
          not is_number(val) ->
            {:type_error, "`#{key}` is not a valid number"}

          has_max !== nil && val > has_max ->
            {:validation_error, "`#{key}` must be less than or equal to #{has_max}"}

          has_min !== nil && val < has_min ->
            {:validation_error, "`#{key}` must be greater than or equal to #{has_min}"}

          true ->
            {:ok, val}
        end
    end
  end

  def validate_type(:boolean, key, val, opts) do
    has_required = Map.get(opts, :required)

    case {has_required, val} do
      {false, nil} ->
        {:ok, val}

      {true, nil} ->
        {:validation_error, "`#{key}` is required"}

      _ ->
        cond do
          not is_boolean(val) ->
            {:type_error, "`#{key}` is not a valid boolean"}

          true ->
            {:ok, val}
        end
    end
  end

  def validate_type(:regex, key, val, opts) do
    has_required = Map.get(opts, :required)
    has_expression = Map.get(opts, :exp)
    has_custom_msg = Map.get(opts, :msg)

    case {has_required, val} do
      {false, nil} ->
        {:ok, val}

      {true, nil} ->
        {:validation_error, "`#{key}` is required"}

      _ ->
        cond do
          has_expression !== nil and not Regex.match?(has_expression, val) ->
            {:type_error, has_custom_msg || "`#{key}` didn't match pattern"}

          true ->
            {:ok, val}
        end
    end
  end

  def validate_type(:map, key, val, opts) do
    has_required = Map.get(opts, :required)
    has_properties = Map.get(opts, :properties)

    case {has_required, val} do
      {false, nil} ->
        {:ok, val}

      {true, nil} ->
        {:validation_error, "`#{key}` is required"}

      _ ->
        cond do
          not is_map(val) ->
            {:type_error, "`#{key}` is not a valid object"}

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
end
