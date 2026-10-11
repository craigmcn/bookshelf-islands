require "test_helper"

class NotificationsControllerTest < ActionDispatch::IntegrationTest
  test "guest is redirected to sign in" do
    get notifications_url
    assert_redirected_to sign_in_path
  end

  test "index shows only the current user's notifications" do
    Follow.create!(follower: users(:member), followed: users(:moderator))
    Follow.create!(follower: users(:admin), followed: users(:member))

    sign_in_as users(:moderator)
    get notifications_url

    assert_response :success
    assert_match users(:member).display_name, response.body
  end

  test "index is empty for a user with no notifications" do
    sign_in_as users(:member)
    get notifications_url

    assert_response :success
    assert_match "You don't have any notifications yet.", response.body
  end

  test "update marks a notification read and redirects to its target" do
    Follow.create!(follower: users(:member), followed: users(:moderator))
    notification = users(:moderator).notifications.last

    sign_in_as users(:moderator)
    patch notification_url(notification)

    assert notification.reload.read?
    assert_redirected_to user_url(users(:member))
  end

  test "index renders with several notifications whose message reaches a nested notifiable association" do
    ReviewComment.create!(user: users(:moderator), reading: readings(:one), body: "Nice review!")
    ReviewComment.create!(user: users(:admin), reading: readings(:one), body: "Agreed!")

    club = Club.create!(name: "Classics Club", book: books(:two), created_by: users(:admin))
    club.club_memberships.create!(user: readings(:one).user)
    ClubPost.create!(club: club, user: users(:admin), body: "Excited to start!")
    ClubPost.create!(club: club, user: users(:admin), body: "Chapter 1 thoughts?")

    sign_in_as readings(:one).user
    get notifications_url

    assert_response :success
  end

  test "update redirects to the buddy read for a buddy_read_invite notification" do
    buddy_read = BuddyRead.create!(book: books(:one), initiator: users(:member), partner: users(:moderator))
    notification = users(:moderator).notifications.last

    sign_in_as users(:moderator)
    patch notification_url(notification)

    assert notification.reload.read?
    assert_redirected_to buddy_read_url(buddy_read)
  end

  test "update redirects to the buddy read for a buddy_read_message notification" do
    buddy_read = BuddyRead.create!(book: books(:one), initiator: users(:member), partner: users(:moderator))
    message = BuddyReadMessage.create!(buddy_read: buddy_read, user: users(:moderator), body: "Hey!")
    notification = users(:member).notifications.find_by!(notifiable: message)

    sign_in_as users(:member)
    patch notification_url(notification)

    assert notification.reload.read?
    assert_redirected_to buddy_read_url(buddy_read)
  end

  test "a user cannot mark another user's notification read" do
    Follow.create!(follower: users(:member), followed: users(:moderator))
    notification = users(:moderator).notifications.last

    sign_in_as users(:admin)
    patch notification_url(notification)

    assert_response :not_found
    assert_not notification.reload.read?
  end

  test "mark_all_read marks every unread notification read" do
    Follow.create!(follower: users(:member), followed: users(:admin))
    Follow.create!(follower: users(:moderator), followed: users(:admin))

    sign_in_as users(:admin)
    patch mark_all_read_notifications_url

    assert_redirected_to notifications_url
    assert_empty users(:admin).notifications.unread
  end
end
