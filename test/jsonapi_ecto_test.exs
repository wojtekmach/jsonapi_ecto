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
      "author": {
        "links": {
          "self": "http://example.com/articles/1/relationships/author",
          "related": "http://example.com/articles/1/author"
        },
        "data": { "type": "people", "id": "9" }
      },
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
    "type": "people",
    "id": "9",
    "attributes": {
      "first-name": "Dan",
      "last-name": "Gebhardt",
      "twitter": "dgeb"
    },
    "links": {
      "self": "http://example.com/people/9"
    }
  }, {
    "type": "comments",
    "id": "5",
    "attributes": {
      "body": "First!"
    },
    "relationships": {
      "author": {
        "data": { "type": "people", "id": "2" }
      }
    },
    "links": {
      "self": "http://example.com/comments/5"
    }
  }, {
    "type": "comments",
    "id": "12",
    "attributes": {
      "body": "I like XML better"
    },
    "relationships": {
      "author": {
        "data": { "type": "people", "id": "9" }
      }
    },
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
    belongs_to :author, Person
  end
end

defmodule Comment do
  use Ecto.Schema

  schema "comments" do
    field :body, :string

    belongs_to :author, Person
  end
end

defmodule Person do
  use Ecto.Schema

  schema "people" do
    field :first_name, :string
    field :last_name, :string
    field :twitter, :string
  end
end

defmodule JSONAPI.EctoTest do
  use ExUnit.Case, async: false
  import Ecto.Query

  test "works" do
    [article] =
      from(a in Article)
      |> TestRepo.all(client: FakeClient)

    # article
    assert article.id == "1"
    assert article.title == "JSON API paints my bikeshed!"
    # author
    assert %Person{id: "9", first_name: "Dan", last_name: "Gebhardt", twitter: "dgeb"} = article.author
    # comments
    [comment1,comment2] = article.comments
    assert comment1.body == "First!"
    assert %Ecto.Association.NotLoaded{} = comment1.author
    assert comment2.body == "I like XML better"
    assert %Person{id: "9", first_name: "Dan"} = comment2.author
  end

  test "select some fields" do
    articles =
      from(a in Article, select: {a.id, a.title})
      |> TestRepo.all(client: FakeClient)

    assert articles == [{"1", "JSON API paints my bikeshed!"}]
  end
end
