require "test_helper"

class BuddyReadMessageTest < ActiveSupport::TestCase
  setup do
    @buddy_read = BuddyRead.create!(book: books(:one), initiator: users(:member), partner: users(:moderator))
  end

  test "valid with a buddy_read, user, and body" do
    assert BuddyReadMessage.new(buddy_read: @buddy_read, user: users(:member), body: "Chapter 1 was great!").valid?
  end

  test "invalid without a body" do
    assert_not BuddyReadMessage.new(buddy_read: @buddy_read, user: users(:member)).valid?
  end

  test "invalid with a body over 1000 characters" do
    assert_not BuddyReadMessage.new(buddy_read: @buddy_read, user: users(:member), body: "a" * 1001).valid?
  end

  test "creating a message notifies the other participant, not the sender" do
    message = BuddyReadMessage.create!(buddy_read: @buddy_read, user: users(:member), body: "Loving this so far!")

    assert_equal "buddy_read_message", message.notification.notification_type
    assert_equal users(:moderator), message.notification.recipient
    assert_equal users(:member), message.notification.actor
  end

  test "a reply from the other participant notifies the original initiator" do
    message = BuddyReadMessage.create!(buddy_read: @buddy_read, user: users(:moderator), body: "Me too!")

    assert_equal users(:member), message.notification.recipient
    assert_equal users(:moderator), message.notification.actor
  end

  test "destroying a message destroys its notification" do
    message = BuddyReadMessage.create!(buddy_read: @buddy_read, user: users(:member), body: "Loving this so far!")
    notification_id = message.notification.id

    message.destroy!

    assert_not Notification.exists?(notification_id)
  end
end
