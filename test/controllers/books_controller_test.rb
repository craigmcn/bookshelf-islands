require "test_helper"

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
end
