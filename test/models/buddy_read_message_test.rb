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
end
