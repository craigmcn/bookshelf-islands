require "test_helper"

class BookSearchControllerTest < ActionDispatch::IntegrationTest
  test "guest is redirected to sign in" do
    get book_search_url(q: "hobbit")
    assert_redirected_to sign_in_path
  end

  test "returns matching results as json" do
    sign_in_as users(:member)
    results = [{title: "The Hobbit", author: "J.R.R. Tolkien", cover_url: "https://covers.openlibrary.org/b/id/1-M.jpg"}]

    original_search = OpenLibraryService.method(:search)
    OpenLibraryService.define_singleton_method(:search) { |*| results }
    get book_search_url(q: "hobbit", format: :json)

    assert_response :success
    assert_equal results.as_json, JSON.parse(response.body)
  ensure
    OpenLibraryService.define_singleton_method(:search, original_search)
  end

  test "returns an empty array for a blank query" do
    sign_in_as users(:member)

    get book_search_url(q: "", format: :json)

    assert_response :success
    assert_equal [], JSON.parse(response.body)
  end
end
