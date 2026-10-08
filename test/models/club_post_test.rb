require "test_helper"

class ClubPostTest < ActiveSupport::TestCase
  setup do
    @club = Club.create!(name: "Classics Club", book: books(:one), created_by: users(:member))
  end

  test "a non-spoiler post is visible to anyone" do
    post = ClubPost.create!(club: @club, user: users(:member), body: "Great book!")
    assert post.visible_to?(users(:admin))
    assert post.visible_to?(nil)
  end

  test "a spoiler post is hidden from someone who hasn't finished the book" do
    other_member = User.create!(email: "other@example.com", password: User::DEFAULT_PASSWORD)
    post = ClubPost.create!(club: @club, user: users(:member), body: "The ending!", spoiler: true)
    assert_not post.visible_to?(other_member)
  end

  test "a spoiler post is visible to its author" do
    post = ClubPost.create!(club: @club, user: users(:member), body: "The ending!", spoiler: true)
    assert post.visible_to?(users(:member))
  end

  test "a spoiler post is visible to a moderator" do
    post = ClubPost.create!(club: @club, user: users(:member), body: "The ending!", spoiler: true)
    assert post.visible_to?(users(:moderator))
  end

  test "a spoiler post is visible to someone who finished the book" do
    other_member = User.create!(email: "other@example.com", password: User::DEFAULT_PASSWORD)
    Reading.create!(user: other_member, book: books(:one), status: :finished)
    post = ClubPost.create!(club: @club, user: users(:member), body: "The ending!", spoiler: true)
    assert post.visible_to?(other_member)
  end

  test "a spoiler post is hidden from a guest" do
    post = ClubPost.create!(club: @club, user: users(:member), body: "The ending!", spoiler: true)
    assert_not post.visible_to?(nil)
  end

  test "creating a post notifies every other member, not the poster" do
    @club.club_memberships.create!(user: users(:moderator))
    @club.club_memberships.create!(user: users(:admin))

    assert_difference "Notification.count", 2 do
      ClubPost.create!(club: @club, user: users(:member), body: "Great book!")
    end

    recipients = Notification.where(notification_type: "club_post").pluck(:recipient_id)
    assert_equal [users(:moderator).id, users(:admin).id].sort, recipients.sort
  end

  test "destroying the post destroys its notifications" do
    @club.club_memberships.create!(user: users(:moderator))
    post = ClubPost.create!(club: @club, user: users(:member), body: "Great book!")

    assert_difference "Notification.count", -1 do
      post.destroy
    end
  end
end
