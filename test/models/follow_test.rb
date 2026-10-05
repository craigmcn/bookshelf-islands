require "test_helper"

class FollowTest < ActiveSupport::TestCase
  test "valid with distinct follower and followed" do
    follow = Follow.new(follower: users(:member), followed: users(:moderator))
    assert follow.valid?
  end

  test "invalid following yourself" do
    follow = Follow.new(follower: users(:member), followed: users(:member))
    assert_not follow.valid?
  end

  test "invalid with a duplicate follow" do
    Follow.create!(follower: users(:member), followed: users(:moderator))
    duplicate = Follow.new(follower: users(:member), followed: users(:moderator))
    assert_not duplicate.valid?
  end

  test "User#following? reflects an active follow" do
    member = users(:member)
    moderator = users(:moderator)
    assert_not member.following?(moderator)

    Follow.create!(follower: member, followed: moderator)
    assert member.reload.following?(moderator)
  end

  test "a new follow creates a notification for the followed user" do
    assert_difference "Notification.count", 1 do
      Follow.create!(follower: users(:member), followed: users(:moderator))
    end

    notification = Notification.last
    assert_equal users(:moderator), notification.recipient
    assert_equal users(:member), notification.actor
    assert notification.new_follower?
    assert_not notification.read?
  end

  test "unfollowing destroys the associated notification" do
    follow = Follow.create!(follower: users(:member), followed: users(:moderator))

    assert_difference "Notification.count", -1 do
      follow.destroy
    end
  end

  test "deleting the follower destroys the follow and its notification without a foreign key error" do
    follower = User.create!(email: "willdelete@example.com", password: User::DEFAULT_PASSWORD)
    Follow.create!(follower: follower, followed: users(:moderator))
    User.deleted_placeholder # pre-create so the assertion below isn't masked by its own +1

    assert_difference ["Follow.count", "Notification.count"], -1 do
      follower.delete_account!
    end
  end

  test "deleting the followed user destroys the follow and its notification without a foreign key error" do
    followed = User.create!(email: "willbedeleted@example.com", password: User::DEFAULT_PASSWORD)
    Follow.create!(follower: users(:member), followed: followed)
    User.deleted_placeholder # pre-create so the assertion below isn't masked by its own +1

    assert_difference ["Follow.count", "Notification.count"], -1 do
      followed.delete_account!
    end
  end
end
