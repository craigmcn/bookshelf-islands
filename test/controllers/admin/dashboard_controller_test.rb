require "test_helper"

class Admin::DashboardControllerTest < ActionDispatch::IntegrationTest
  test "guest is redirected to sign in" do
    get admin_root_url
    assert_redirected_to sign_in_path
  end

  test "member gets forbidden" do
    sign_in_as users(:member)
    get admin_root_url
    assert_response :forbidden
  end

  test "admin can access the dashboard" do
    sign_in_as users(:admin)
    get admin_root_url
    assert_response :success
  end

  test "admin dashboard renders trend charts" do
    sign_in_as users(:admin)
    get admin_root_url
    assert_response :success
    assert_select "h3", text: "Trends"
  end

  test "popular books show each book's reading count without a query per book" do
    # two books with readings, so Bullet (raises in test) sees a per-book COUNT as an N+1
    Reading.create!(user: users(:moderator), book: books(:two), status: :reading)
    Reading.create!(user: users(:admin), book: books(:two), status: :finished)

    sign_in_as users(:admin)
    get admin_root_url

    assert_response :success
    assert_select "tbody tr", 2
    assert_select "tbody tr:first-child .badge", text: "2"
  end

  test "total user count excludes the deleted-user placeholder" do
    starting_count = User.excluding_deleted_placeholder.count
    User.deleted_placeholder

    sign_in_as users(:admin)
    get admin_root_url

    assert_response :success
    assert_select ".display-4.text-primary", text: starting_count.to_s
  end
end
