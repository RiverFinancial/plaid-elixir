defmodule Plaid.ResponseMapper do
  @moduledoc false

  @spec transform(term(), struct() | list()) :: term()
  def transform(value, template) when is_map(value) or is_list(value) do
    map_value(value, template)
  end

  def transform(value, _template), do: value

  defp map_value(nil, _template), do: nil

  defp map_value(value, %module{} = template) do
    defaults = struct(module)

    template
    |> Map.from_struct()
    |> Enum.reduce(defaults, fn {field, shape}, result ->
      mapped =
        case Map.get(value, Atom.to_string(field), shape) do
          ^shape when is_map(shape) or is_list(shape) -> Map.fetch!(defaults, field)
          nested when is_map(nested) or is_list(nested) -> map_value(nested, shape)
          scalar -> scalar
        end

      Map.put(result, field, mapped)
    end)
  end

  defp map_value(values, [template]) do
    Enum.map(values, &map_value(&1, template))
  end

  defp map_value(value, _template), do: value
end
