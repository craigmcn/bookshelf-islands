require "test_helper"

# Follow/ReviewComment/BuddyRead already have real triggers, each tested in its
# own file (e.g. "a new follow creates a notification"); ClubPost is still the
# one notification_type with no trigger (lands in the final Social PR). These
# tests build Notification records directly rather than through a trigger —
# the recipient themself stands in for `notifiable` below, since that's enough
# to exercise the model's own behavior independent of any one trigger.
class NotificationTest < ActiveSupport::TestCase
  def build_notification(**attrs)
    Notification.new(
      recipient: users(:moderator),
      actor: users(:member),
      notifiable: users(:moderator),
      notification_type: "new_follower",
      **attrs
    )
  end

  test "valid with recipient, actor, notifiable, and notification_type" do
    assert build_notification.valid?
  end

  test "invalid without notification_type" do
    assert_not build_notification(notification_type: nil).valid?
  end

  test "read? is false and mark_read! sets read_at only once" do
    notification = build_notification.tap(&:save!)
    assert_not notification.read?

    notification.mark_read!
    read_at = notification.read_at
    assert notification.read?

    notification.mark_read!
    assert_equal read_at, notification.reload.read_at
  end

  test "unread scope excludes read notifications" do
    unread = build_notification.tap(&:save!)
    read = build_notification.tap(&:save!).tap(&:mark_read!)

    assert_includes Notification.unread, unread
    assert_not_includes Notification.unread, read
  end

  test "recent scope orders newest first" do
    older = build_notification.tap(&:save!)
    older.update_column(:created_at, 1.day.ago)
    newer = build_notification.tap(&:save!)

    assert_equal [newer, older], Notification.recent.to_a
  end

  test "not_yet_digested scope excludes digested notifications" do
    pending = build_notification.tap(&:save!)
    digested = build_notification.tap(&:save!).tap { |n| n.update!(digested_at: Time.current) }

    assert_includes Notification.not_yet_digested, pending
    assert_not_includes Notification.not_yet_digested, digested
  end

  test "message, target_type, and target_id for new_follower" do
    notification = build_notification.tap(&:save!)

    assert_equal "#{users(:member).display_name} started following you", notification.message
    assert_equal "user", notification.target_type
    assert_equal users(:member).id, notification.target_id
  end

  test "message, target_type, and target_id for buddy_read_invite" do
    buddy_read = BuddyRead.create!(book: books(:one), initiator: users(:member), partner: users(:moderator))
    notification = Notification.where(notification_type: "buddy_read_invite", notifiable: buddy_read).last

    assert_equal "#{users(:member).display_name} invited you to a buddy read of #{books(:one).title}", notification.message
    assert_equal "buddy_read", notification.target_type
    assert_equal buddy_read.id, notification.target_id
  end
end
