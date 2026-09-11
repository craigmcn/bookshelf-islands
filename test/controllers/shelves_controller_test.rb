require "test_helper"

class ShelvesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @shelf = shelves(:one)
  end

  test "guest is redirected to sign in" do
    get shelves_url
    assert_redirected_to sign_in_path
  end

  test "member can view their lists" do
    sign_in_as users(:member)
    get shelves_url
    assert_response :success
  end

  test "member can create a list" do
    sign_in_as users(:member)
    assert_difference "Shelf.count" do
      post shelves_url, params: {shelf: {name: "2026 TBR"}}
    end
    assert_redirected_to shelf_url(Shelf.last)
  end

  test "member cannot view another user's list" do
    sign_in_as users(:admin)
    get shelf_url(@shelf)
    assert_response :not_found
  end

  test "member can rename their own list" do
    sign_in_as users(:member)
    patch shelf_url(@shelf), params: {shelf: {name: "Renamed"}}
    assert_redirected_to shelf_url(@shelf)
    assert_equal "Renamed", @shelf.reload.name
  end

  test "member can delete their own list" do
    sign_in_as users(:member)
    assert_difference "Shelf.count", -1 do
      delete shelf_url(@shelf)
    end
    assert_redirected_to shelves_url
  end
end
