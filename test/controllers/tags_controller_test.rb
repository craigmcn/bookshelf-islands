require "test_helper"

class TagsControllerTest < ActionDispatch::IntegrationTest
  test "guest is redirected to sign in" do
    get tags_url(q: "fan")
    assert_redirected_to sign_in_path
  end

  test "member gets matching genre tag names" do
    sign_in_as users(:member)
    get tags_url(q: "fan"), as: :json

    assert_response :success
    assert_equal [tags(:one).name], JSON.parse(response.body)
  end

  test "member gets an empty array for a blank query" do
    sign_in_as users(:member)
    get tags_url, as: :json

    assert_equal [], JSON.parse(response.body)
  end
end
