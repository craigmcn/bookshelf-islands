require "test_helper"

class ShelfBooksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @shelf = shelves(:one)
    @book = books(:one)
  end

  test "guest is redirected to sign in" do
    post shelf_shelf_books_url(@shelf), params: {book_id: @book.id}
    assert_redirected_to sign_in_path
  end

  test "owner can add a book to their list via JSON (shelf picker island)" do
    sign_in_as users(:member)
    assert_difference "ShelfBook.count" do
      post shelf_shelf_books_url(@shelf), params: {book_id: @book.id}, as: :json
    end
    assert_response :created
    body = JSON.parse(response.body)
    assert_equal @shelf.id, body["shelf_id"]
    assert_equal @book.id, body["book_id"]
  end

  test "adding the same book twice does not duplicate it" do
    sign_in_as users(:member)
    post shelf_shelf_books_url(@shelf), params: {book_id: @book.id}, as: :json

    assert_no_difference "ShelfBook.count" do
      post shelf_shelf_books_url(@shelf), params: {book_id: @book.id}, as: :json
    end
    assert_response :created
  end

  test "owner can remove a book from their list via JSON" do
    sign_in_as users(:member)
    shelf_book = ShelfBook.create!(shelf: @shelf, book: @book)

    assert_difference "ShelfBook.count", -1 do
      delete shelf_shelf_book_url(@shelf, shelf_book), as: :json
    end
    assert_response :no_content
  end

  test "a non-owner cannot add a book to someone else's list" do
    sign_in_as users(:admin)
    assert_no_difference "ShelfBook.count" do
      post shelf_shelf_books_url(@shelf), params: {book_id: @book.id}, as: :json
    end
    assert_response :not_found
  end
end
