require "test_helper"

class ClubPostsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @club = Club.create!(name: "Classics Club", book: books(:one), created_by: users(:member))
  end

  test "member can post to a club they belong to" do
    sign_in_as users(:member)

    assert_difference "@club.club_posts.count" do
      post club_posts_url(@club), params: {club_post: {body: "Great book!"}}
    end

    assert_redirected_to club_url(@club)
  end

  test "non-member cannot post to a club" do
    sign_in_as users(:admin)

    assert_no_difference "@club.club_posts.count" do
      post club_posts_url(@club), params: {club_post: {body: "Butting in!"}}
    end

    assert_redirected_to root_url
  end

  test "post author can delete their own post" do
    club_post = ClubPost.create!(club: @club, user: users(:member), body: "Great book!")
    sign_in_as users(:member)

    assert_difference "@club.club_posts.count", -1 do
      delete club_post_url(@club, club_post)
    end

    assert_redirected_to club_url(@club)
  end

  test "moderator can delete another member's post" do
    club_post = ClubPost.create!(club: @club, user: users(:member), body: "Great book!")
    sign_in_as users(:moderator)

    assert_difference "@club.club_posts.count", -1 do
      delete club_post_url(@club, club_post)
    end

    assert_redirected_to club_url(@club)
  end
end
