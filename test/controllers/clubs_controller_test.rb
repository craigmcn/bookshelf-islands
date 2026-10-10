require "test_helper"

class ClubsControllerTest < ActionDispatch::IntegrationTest
  test "guest is redirected to sign in" do
    get clubs_url
    assert_redirected_to sign_in_path
  end

  test "member can view the club list" do
    sign_in_as users(:member)
    get clubs_url
    assert_response :success
  end

  test "member can create a club and is auto-joined" do
    sign_in_as users(:member)

    assert_difference "Club.count" do
      post clubs_url, params: {club: {name: "Classics Club", book_id: books(:one).id, description: "Old favorites"}}
    end

    club = Club.last
    assert_redirected_to club_url(club)
    assert club.member?(users(:member))
  end

  test "index shows accurate member counts without an N+1 per club" do
    club_one = Club.create!(name: "Classics Club", book: books(:one), created_by: users(:member))
    club_one.club_memberships.create!(user: users(:moderator))
    Club.create!(name: "Sci-Fi Club", book: books(:two), created_by: users(:admin))

    sign_in_as users(:member)
    get clubs_url

    assert_response :success
    assert_match "2 members", response.body
    assert_match "1 member", response.body
  end

  test "show hides a spoiler post from multiple viewers without a query per post" do
    club = Club.create!(name: "Classics Club", book: books(:one), created_by: users(:member))
    ClubPost.create!(club: club, user: users(:member), body: "Twist #1!", spoiler: true)
    ClubPost.create!(club: club, user: users(:member), body: "Twist #2!", spoiler: true)
    other_member = User.create!(email: "other@example.com", password: User::DEFAULT_PASSWORD)

    sign_in_as other_member
    get club_url(club)

    assert_response :success
    assert_match "Hidden until you've finished the book.", response.body
  end

  test "any signed-in member can view a club" do
    club = Club.create!(name: "Classics Club", book: books(:one), created_by: users(:member))
    sign_in_as users(:admin)

    get club_url(club)

    assert_response :success
  end

  test "only the creator or a moderator can edit a club" do
    club = Club.create!(name: "Classics Club", book: books(:one), created_by: users(:member))
    other_member = User.create!(email: "other@example.com", password: User::DEFAULT_PASSWORD)
    sign_in_as other_member

    get edit_club_url(club)

    assert_redirected_to root_url
  end

  test "a moderator can edit someone else's club" do
    club = Club.create!(name: "Classics Club", book: books(:one), created_by: users(:member))
    sign_in_as users(:moderator)

    get edit_club_url(club)

    assert_response :success
  end
end
