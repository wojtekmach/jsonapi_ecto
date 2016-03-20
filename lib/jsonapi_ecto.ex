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

  def execute(_repo, %{fields: fields, sources: sources}, {:nocache, {:all, query}}, [] = _params, preprocess, opts) do
    client = opts[:client] || @client
    path = Get.new(query)

    response = client.get!(path)
    data = Map.fetch!(response, "data")
    included = Map.fetch!(response, "included")

    items = Enum.map(data, fn item -> process_item(sources, item, included, fields, preprocess) end)

    {0, items}
  end

  defp process_item(_sources, item, _included, [{:&, [], [0, nil, _]}], _preprocess) do
    [item]
  end
  defp process_item(sources, item, included, [{:&, [], [0, field_names, _]}], preprocess) do
    fields = [{:&, [], [0, field_names, nil]}]
    values = extract_values(sources, item, included, field_names)

    [preprocess.(hd(fields), values, nil) |> process_assocs(item, included)]
  end
  defp process_item(_sources, item, _included, exprs, preprocess) do
    Enum.map(exprs, fn {{:., [], [{:&, [], [0]}, field]}, _, []} ->
      if field == :id do
        item["id"]
      else
        preprocess.(field, Map.fetch!(item["attributes"], Atom.to_string(field)), nil)
      end
    end)
  end

  defp extract_values({{_, schema}}, item, _included, field_names) do
    fks = foreign_keys(schema)
    field_names = field_names -- [:id | fks]
    values = Enum.map(field_names, fn field -> Map.fetch!(item["attributes"], Atom.to_string(field)) end)
    [item["id"] | values] ++ Enum.map(fks, fn _ -> "" end)
  end

  defp foreign_keys(schema) do
    fks =
      schema.__schema__(:associations)
      |> Enum.map(fn assoc ->
        case schema.__schema__(:association, assoc) do
          %Ecto.Association.BelongsTo{owner_key: fk} ->
            fk
          _ ->
            nil
        end
      end)
    fks -- [nil]
  end

  defp process_assocs(%{__struct__: struct} = schema, item, included) do
    Enum.map(struct.__schema__(:associations), fn assoc ->
      case struct.__schema__(:association, assoc) do
        %Ecto.Association.BelongsTo{} = info ->
          queryable = info.queryable
          id = item["relationships"]["#{assoc}"]["data"]["id"]
          source = queryable.__schema__(:source)
          item = find_in(included, source, id)

          if item do
            attributes = extract_attributes(info.queryable, item)
            attributes = Map.put(attributes, :id, id)
            value = struct(queryable, attributes)

            {assoc, value}
          else
            # returns the default: Ecto.Association.NotLoaded
            {assoc, Map.get(schema, assoc)}
          end
        %Ecto.Association.Has{cardinality: :many} = info ->
          queryable = info.queryable
          ids = item["relationships"]["#{assoc}"]["data"] |> Enum.map(& &1["id"])

          values =
            Enum.map(ids, fn id ->
              item = find_in(included, "#{assoc}", id)
              value =
                struct(queryable, extract_attributes(info.queryable, item))
                |> process_assocs(item, included)

              value
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

  defp extract_attributes(queryable, item) do
    fields = queryable.__schema__(:fields) |> Enum.map(&Atom.to_string/1)

    Enum.into(item["attributes"], %{}, fn {key, val} ->
      key = String.replace(key, "-", "_")
      if key in fields do
        {String.to_atom(key), val}
      else
        {nil, nil}
      end
    end)
  end

  ## Writes

  def insert(_repo, _meta, _params, _autogen, _opts), do: raise "Not implemented yet"

  def insert_all(_, _, _, _, _, _), do: raise "Not implemented yet"

  def delete(_, _, _, _), do: raise "Not implemented yet"

  def update(_repo, _meta, _params, _filter, _autogen, _opts), do: raise "Not implemented yet"
end
