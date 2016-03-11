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

    response = client.get!(path)
    data = Map.fetch!(response, "data")
    included = Map.fetch!(response, "included")

    items = Enum.map(data, fn item -> process_item(item, included, fields, preprocess) end)

    {0, items}
  end

  defp process_item(item, _included, [{:&, [], [0, nil, _]}], _preprocess) do
    [item]
  end
  defp process_item(item, included, [{:&, [], [0, field_names, _]}], preprocess) do
    fields = [{:&, [], [0, field_names, nil]}]
    values = extract_values(item, included, field_names)

    [preprocess.(hd(fields), values, nil) |> process_assocs(item, included)]
  end
  defp process_item(item, _included, exprs, preprocess) do
    Enum.map(exprs, fn {{:., [], [{:&, [], [0]}, field]}, _, []} ->
      if field == :id do
        item["id"]
      else
        preprocess.(field, Map.fetch!(item["attributes"], Atom.to_string(field)), nil)
      end
    end)
  end

  defp extract_values(item, _included, field_names) do
    # FIXME: remove hardcoded author_id
    field_names = field_names -- [:id, :author_id]
    values = Enum.map(field_names, fn field -> Map.fetch!(item["attributes"], Atom.to_string(field)) end)
    # FIXME: remove [""]
    [item["id"] | values] ++ [""]
  end

  defp process_assocs(%{__struct__: struct} = schema, item, included) do
    Enum.map(struct.__schema__(:associations), fn assoc ->
      case struct.__schema__(:association, assoc) do
        %Ecto.Association.BelongsTo{} = info ->
          queryable = info.queryable
          id = item["relationships"]["#{assoc}"]["data"]["id"]
          source = queryable.__schema__(:source)
          item = find_in(included, source, id)

          attributes = extract_attributes(item)
          attributes = Map.put(attributes, :id, id)
          value = struct(queryable, attributes)

          {assoc, value}
        %Ecto.Association.Has{cardinality: :many} = info ->
          queryable = info.queryable
          ids = item["relationships"]["#{assoc}"]["data"] |> Enum.map(& &1["id"])

          values =
            Enum.map(ids, fn id ->
              item = find_in(included, "#{assoc}", id)
              struct(queryable, extract_attributes(item))
            end)

          {assoc, values}
      end
    end)
    |> Enum.reduce(schema, fn({assoc, assoc_schema}, schema) ->
      Map.put(schema, assoc, assoc_schema)
    end)
  end

  defp find_in(included, type, id) do
    Enum.find(included, fn item -> item["type"] == type && item["id"] == id end)
  end

  defp extract_attributes(item) do
    # TODO: whitelist attributes before String.to_atom
    Enum.into(item["attributes"], %{}, fn {key, val} -> {String.replace(key, "-", "_") |> String.to_atom, val} end)
  end

  ## Writes

  def insert(_repo, _meta, _params, _autogen, _opts), do: raise "Not implemented yet"

  def insert_all(_, _, _, _, _, _), do: raise "Not implemented yet"

  def delete(_, _, _, _), do: raise "Not implemented yet"

  def update(_repo, _meta, _params, _filter, _autogen, _opts), do: raise "Not implemented yet"
end
