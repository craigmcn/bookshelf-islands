require "test_helper"
require "webmock/minitest"

class BooksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @book = books(:one)
  end

  # Public access
  test "anyone can view books index" do
    get books_url
    assert_response :success
  end

  # Search, sort, pagination (JSON API backing the CatalogBrowser island)
  test "catalog json filters by title or author" do
    get books_url(q: "1984", format: :json)
    assert_response :success
    books = JSON.parse(response.body)["books"]
    assert_equal ["1984"], books.pluck("title")
  end

  test "catalog json sorts by author" do
    get books_url(sort: "author", format: :json)
    assert_response :success
    books = JSON.parse(response.body)["books"]
    assert_equal ["F. Scott Fitzgerald", "George Orwell"], books.pluck("author")
  end

  test "catalog json falls back to title sort for an unknown sort key" do
    get books_url(sort: "bogus", format: :json)
    assert_response :success
    assert_equal "title", JSON.parse(response.body)["sort"]
  end

  test "catalog json sorts by publication date with undated books last" do
    @book.update!(published_on: "1925-04-10") # books(:two) has no published_on

    get books_url(sort: "published", format: :json)
    books = JSON.parse(response.body)["books"]
    assert_equal [@book.title, books(:two).title], books.pluck("title")
  end

  test "catalog json filters by tag" do
    @book.update!(tag_list: tags(:one).name)

    get books_url(tag: tags(:one).name, format: :json)
    body = JSON.parse(response.body)
    assert_equal [@book.title], body["books"].pluck("title")
    assert_equal tags(:one).name, body["tag"]
  end

  test "catalog json returns no books for an unknown tag" do
    get books_url(tag: "no-such-tag", format: :json)
    body = JSON.parse(response.body)
    assert_empty body["books"]
    assert_nil body["tag"]
  end

  test "catalog json includes the genre tag list for browsing" do
    get books_url(format: :json)
    body = JSON.parse(response.body)
    assert_equal [tags(:one).name], body["genre_tags"].pluck("name")
  end

  test "catalog json includes mood and pace tag lists for browsing" do
    @book.update!(mood_list: "dark", pace_list: "fast-paced")

    get books_url(format: :json)
    body = JSON.parse(response.body)
    assert_equal ["dark"], body["mood_tags"].pluck("name")
    assert_equal ["fast-paced"], body["pace_tags"].pluck("name")
  end

  test "catalog json filters by a mood tag" do
    @book.update!(mood_list: "dark")

    get books_url(tag: "dark", format: :json)
    body = JSON.parse(response.body)
    assert_equal [@book.title], body["books"].pluck("title")
  end

  test "member can create a book with genre tags" do
    sign_in_as users(:member)
    post books_url, params: {book: {title: "New Book", author: "Some Author", added_by_id: users(:member).id, tag_list: "sci-fi, adventure"}}

    assert_equal ["adventure", "sci-fi"], Book.last.tags.order(:name).pluck(:name)
  end

  test "member creating a book with an open_library_key pulls in description and subjects" do
    stub_request(:get, "https://openlibrary.org/works/OL468431W.json")
      .to_return(
        status: 200,
        headers: {"Content-Type" => "application/json"},
        body: {description: "A novel about the American Dream.", subjects: ["Fiction", "Classics"]}.to_json
      )

    sign_in_as users(:member)
    assert_difference "Book.count" do
      post books_url, params: {book: {
        title: "New Book", author: "Some Author", added_by_id: users(:member).id, cover_url: "",
        open_library_key: "/works/OL468431W"
      }}
    end
    assert_redirected_to book_url(Book.last)

    book = Book.last
    assert_equal "A novel about the American Dream.", book.description
    assert_equal ["Fiction", "Classics"], book.subjects
  end

  test "open_library_key round-trips through a failed create so a retry can still fetch detail" do
    stub_request(:get, "https://openlibrary.org/works/OL468431W.json")
      .to_return(status: 200, headers: {"Content-Type" => "application/json"}, body: "{}")

    sign_in_as users(:member)
    assert_no_difference "Book.count" do
      post books_url, params: {book: {
        title: "", author: "Some Author", cover_url: "", open_library_key: "/works/OL468431W"
      }}
    end
    assert_response :unprocessable_content
    assert_select "input[name=?][value=?]", "book[open_library_key]", "/works/OL468431W"
  end

  test "admin can update a book's isbn, page_count, and published_on" do
    sign_in_as users(:admin)
    patch book_url(@book), params: {book: {
      title: @book.title, author: @book.author, added_by_id: @book.added_by_id, cover_url: @book.cover_url,
      isbn: "978-0743273565", page_count: 180, published_on: "1925-04-10"
    }}

    assert_redirected_to book_url(@book)
    @book.reload
    assert_equal "978-0743273565", @book.isbn
    assert_equal 180, @book.page_count
    assert_equal Date.new(1925, 4, 10), @book.published_on
  end

  test "admin can assign a book to a series" do
    sign_in_as users(:admin)
    patch book_url(@book), params: {book: {
      title: @book.title, author: @book.author, added_by_id: @book.added_by_id, cover_url: @book.cover_url,
      series_id: series(:one).id, series_position: 2
    }}

    @book.reload
    assert_equal series(:one), @book.series
    assert_equal 2, @book.series_position
  end

  test "member can create a book with mood and pace tags" do
    sign_in_as users(:member)
    post books_url, params: {book: {title: "New Book", author: "Some Author", added_by_id: users(:member).id, mood_list: "hopeful", pace_list: "slow-burn"}}

    book = Book.last
    assert_equal ["hopeful"], book.tags.mood.pluck(:name)
    assert_equal ["slow-burn"], book.tags.pace.pluck(:name)
  end

  test "catalog json paginates results" do
    14.times { |n| Book.create!(title: "Extra #{n}", author: "Someone", added_by: users(:member)) }

    get books_url(format: :json)
    body = JSON.parse(response.body)
    assert_equal 12, body["books"].length
    assert_equal 2, body["pagy"]["pages"]

    get books_url(page: 2, format: :json)
    body = JSON.parse(response.body)
    assert_equal 4, body["books"].length
  end

  test "anyone can view a book" do
    get book_url(@book)
    assert_response :success
  end

  test "book show renders similar books sharing a tag" do
    similar = Book.create!(title: "Similar Book", author: "A. Uthor", added_by: users(:member))
    similar.taggings.create!(tag: tags(:one))

    get book_url(@book)
    assert_response :success
    assert_match(/Similar Book/, response.body)
  end

  test "signed-in member sees their lists and which ones contain the book (shelf picker island)" do
    sign_in_as users(:member) # @book is already on shelves(:one) via the shelf_books fixture
    Shelf.create!(user: users(:member), name: "2026 TBR")

    get book_url(@book)
    assert_response :success
    assert_match(/#{shelves(:one).name}/, response.body)
    assert_match(/2026 TBR/, response.body)
  end

  # Auth wall
  test "guest is redirected to sign in for new" do
    get new_book_url
    assert_redirected_to sign_in_path
  end

  test "guest is redirected to sign in for create" do
    post books_url, params: {book: {title: "New", author: "Author", added_by_id: users(:member).id}}
    assert_redirected_to sign_in_path
  end

  # Member permissions
  test "member can create a book" do
    sign_in_as users(:member)
    assert_difference "Book.count" do
      post books_url, params: {book: {title: "New Book", author: "Some Author", added_by_id: users(:member).id, cover_url: ""}}
    end
    assert_redirected_to book_url(Book.last)
  end

  test "member cannot update a book" do
    sign_in_as users(:member)
    patch book_url(@book), params: {book: {title: "Changed", author: @book.author, added_by_id: @book.added_by_id, cover_url: @book.cover_url}}
    assert_response :redirect
    assert_not_equal "Changed", @book.reload.title
  end

  test "member cannot destroy a book" do
    sign_in_as users(:member)
    assert_no_difference "Book.count" do
      delete book_url(@book)
    end
  end

  # Admin permissions
  test "admin can update a book" do
    sign_in_as users(:admin)
    patch book_url(@book), params: {book: {title: "Updated", author: @book.author, added_by_id: @book.added_by_id, cover_url: @book.cover_url}}
    assert_redirected_to book_url(@book)
    assert_equal "Updated", @book.reload.title
  end

  test "admin can destroy a book" do
    sign_in_as users(:admin)
    assert_difference "Book.count", -1 do
      delete book_url(@book)
    end
    assert_redirected_to books_url
  end

  test "View on Shelf links to the newest of several readings of a book" do
    sign_in_as users(:member)
    reread = Reading.create!(user: users(:member), book: books(:one), status: :want_to_read)
    get book_url(books(:one))
    assert_select "a[href=?]", reading_path(reread), text: /View on Shelf/
    assert_select "a[href=?]", new_reading_path(book_id: books(:one).id), text: /Log a Re-read/
  end

  test "catalog hands the island an unknown tag so it stays applied and clearable" do
    get books_url(tag: "no-such-tag")
    assert_select "[data-catalog-browser-tag-value=?]", "no-such-tag"
  end
end
