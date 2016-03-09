defmodule FakeClient do
  def get!(_path) do
    # taken from http://jsonapi.org
    """
{
  "links": {
    "self": "http://example.com/articles",
    "next": "http://example.com/articles?page[offset]=2",
    "last": "http://example.com/articles?page[offset]=10"
  },
  "data": [{
    "type": "articles",
    "id": "1",
    "attributes": {
      "title": "JSON API paints my bikeshed!"
    },
    "relationships": {},
    "links": {
      "self": "http://example.com/articles/1"
    }
  }],
  "included": []
}
    """
    |> Poison.decode!
  end
end

defmodule Article do
  use Ecto.Schema

  schema "articles" do
    field :title, :string
  end
end

defmodule JSONAPI.EctoTest do
  use ExUnit.Case, async: false
  import Ecto.Query

  test "works" do
    articles =
      from(a in Article)
      |> TestRepo.all(client: FakeClient)

    assert [%Article{id: "1", title: "JSON API paints my bikeshed!"}] = articles
  end
end
