defmodule JSONAPI.Ecto do
  alias JSONAPI.Ecto.Get

  @client Application.get_env(:jsonapi_ecto, :client)

  ## Boilerplate

  @behaviour Ecto.Adapter

  defmacro __before_compile__(_opts), do: :ok

  def application do
    :jsonapi_ecto
  end

  def child_spec(_repo, _opts) do
    Supervisor.Spec.worker(JSONAPI.Ecto.Client, [])
  end

  def stop(_, _, _), do: :ok

  def loaders(primitive, _type), do: [primitive]

  def dumpers(primitive, _type), do: [primitive]

  def embed_id(_), do: ObjectID.generate

  def prepare(operation, query), do: {:nocache, {operation, query}}

  def autogenerate(_), do: raise "Not supported by adapter"

  ## Reads

  def execute(_repo, %{fields: fields} = _meta, {:nocache, {:all, query}}, [] = _params, preprocess, opts) do
    client = opts[:client] || @client
    path = Get.new(query)

    items =
      client.get!(path)
      |> Map.fetch!("data")
      |> Enum.map(fn item -> process_item(item, fields, preprocess) end)

    {0, items}
  end

  defp process_item(item, [{:&, [], [0, nil, _]}], _preprocess) do
    [item]
  end
  defp process_item(item, [{:&, [], [0, field_names, _]}], preprocess) do
    fields = [{:&, [], [0, field_names, nil]}]
    values = Enum.map(field_names -- [:id], fn field -> Map.fetch!(item["attributes"], Atom.to_string(field)) end)
    values = [item["id"] | values]
    [preprocess.(hd(fields), values, nil)]
  end
  defp process_item(item, exprs, preprocess) do
    Enum.map(exprs, fn {{:., [], [{:&, [], [0]}, field]}, _, []} ->
      preprocess.(field, Map.fetch!(item, Atom.to_string(field)), nil)
    end)
  end

  ## Writes

  def insert(_repo, _meta, _params, _autogen, _opts), do: raise "Not implemented yet"

  def insert_all(_, _, _, _, _, _), do: raise "Not implemented yet"

  def delete(_, _, _, _), do: raise "Not implemented yet"

  def update(_repo, _meta, _params, _filter, _autogen, _opts), do: raise "Not implemented yet"
end
