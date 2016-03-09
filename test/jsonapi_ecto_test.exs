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
    "relationships": {
      "comments": {
        "links": {
          "self": "http://example.com/articles/1/relationships/comments",
          "related": "http://example.com/articles/1/comments"
        },
        "data": [
          { "type": "comments", "id": "5" },
          { "type": "comments", "id": "12" }
        ]
      }
    },
    "links": {
      "self": "http://example.com/articles/1"
    }
  }],
  "included": [{
    "type": "comments",
    "id": "5",
    "attributes": {
      "body": "First!"
    },
    "relationships": {},
    "links": {
      "self": "http://example.com/comments/5"
    }
  }, {
    "type": "comments",
    "id": "12",
    "attributes": {
      "body": "I like XML better"
    },
    "relationships": {},
    "links": {
      "self": "http://example.com/comments/12"
    }
  }]
}
    """
    |> Poison.decode!
  end
end

defmodule Article do
  use Ecto.Schema

  schema "articles" do
    field :title, :string

    has_many :comments, Comment
  end
end

defmodule Comment do
  use Ecto.Schema

  schema "comments" do
    field :body, :string
  end
end

defmodule JSONAPI.EctoTest do
  use ExUnit.Case, async: false
  import Ecto.Query

  test "works" do
    articles =
      from(a in Article)
      |> TestRepo.all(client: FakeClient)

    comments = [%Comment{body: "First!"}, %Comment{body: "I like XML better"}]
    assert [%Article{id: "1", title: "JSON API paints my bikeshed!", comments: ^comments}] = articles
  end
end
