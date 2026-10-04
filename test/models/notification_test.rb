require "test_helper"

# No notification trigger exists yet (Follow/ReviewComment/ClubPost all land in
# later PRs as the Social roadmap category is ported), so these tests build
# Notification records directly rather than through a trigger — the recipient
# themself stands in for `notifiable` below, since nothing else real exists to
# point the polymorphic association at yet. Trigger-specific tests (e.g. "a new
# follow creates a notification") belong in each feature's own test file once
# it exists.
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
end
