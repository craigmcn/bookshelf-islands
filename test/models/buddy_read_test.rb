require "test_helper"

class BuddyReadTest < ActiveSupport::TestCase
  test "valid with distinct initiator and partner" do
    buddy_read = BuddyRead.new(book: books(:one), initiator: users(:member), partner: users(:moderator))
    assert buddy_read.valid?
  end

  test "invalid inviting yourself" do
    buddy_read = BuddyRead.new(book: books(:one), initiator: users(:member), partner: users(:member))
    assert_not buddy_read.valid?
  end

  test "defaults to pending" do
    buddy_read = BuddyRead.create!(book: books(:one), initiator: users(:member), partner: users(:moderator))
    assert buddy_read.pending?
  end

  test "participant? is true for either side" do
    buddy_read = BuddyRead.create!(book: books(:one), initiator: users(:member), partner: users(:moderator))
    assert buddy_read.participant?(users(:member))
    assert buddy_read.participant?(users(:moderator))
    assert_not buddy_read.participant?(users(:admin))
  end

  test "other_participant returns the other side" do
    buddy_read = BuddyRead.create!(book: books(:one), initiator: users(:member), partner: users(:moderator))
    assert_equal users(:moderator), buddy_read.other_participant(users(:member))
    assert_equal users(:member), buddy_read.other_participant(users(:moderator))
  end

  test "messageable? is true for pending, accepted, and completed" do
    buddy_read = BuddyRead.create!(book: books(:one), initiator: users(:member), partner: users(:moderator))
    assert buddy_read.messageable?

    buddy_read.update!(status: :accepted)
    assert buddy_read.messageable?

    buddy_read.update!(status: :completed)
    assert buddy_read.messageable?
  end

  test "messageable? is false for declined and cancelled" do
    buddy_read = BuddyRead.create!(book: books(:one), initiator: users(:member), partner: users(:moderator))

    buddy_read.update!(status: :declined)
    assert_not buddy_read.messageable?

    buddy_read.update!(status: :cancelled)
    assert_not buddy_read.messageable?
  end

  test "creating a buddy read notifies the partner" do
    assert_difference "Notification.count", 1 do
      BuddyRead.create!(book: books(:one), initiator: users(:member), partner: users(:moderator))
    end

    notification = Notification.last
    assert_equal users(:moderator), notification.recipient
    assert_equal users(:member), notification.actor
    assert notification.buddy_read_invite?
  end

  test "destroying the buddy read destroys its notification" do
    buddy_read = BuddyRead.create!(book: books(:one), initiator: users(:member), partner: users(:moderator))

    assert_difference "Notification.count", -1 do
      buddy_read.destroy
    end
  end

  test "deleting the initiator destroys the buddy read and its notification without a foreign key error" do
    initiator = User.create!(email: "willdelete@example.com", password: User::DEFAULT_PASSWORD)
    BuddyRead.create!(book: books(:one), initiator: initiator, partner: users(:moderator))
    User.deleted_placeholder # pre-create so the assertion below isn't masked by its own +1

    assert_difference ["BuddyRead.count", "Notification.count"], -1 do
      initiator.delete_account!
    end
  end

  test "deleting the partner destroys the buddy read and its notification without a foreign key error" do
    partner = User.create!(email: "willbedeleted@example.com", password: User::DEFAULT_PASSWORD)
    BuddyRead.create!(book: books(:one), initiator: users(:member), partner: partner)
    User.deleted_placeholder # pre-create so the assertion below isn't masked by its own +1

    assert_difference ["BuddyRead.count", "Notification.count"], -1 do
      partner.delete_account!
    end
  end
end
