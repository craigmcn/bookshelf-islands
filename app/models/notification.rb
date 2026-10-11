# ported from community_bookshelf app/models/notification.rb
# club_post isn't created by anything yet — Club/ClubPost lands in the final
# PR as the Social roadmap category is ported. Declaring the enum value now
# (rather than growing it piecemeal) matches the reference implementation
# and avoids re-touching this model for that last PR; the case statements
# below simply have an unreachable branch until that trigger exists.
#
# buddy_read_invite has no equivalent in community_bookshelf at all — it
# never notifies on a buddy read invite, discoverable only by visiting the
# index. Added here deliberately as a small improvement on the reference
# (community_bookshelf#199 tracks bringing it back in line).
class Notification < ApplicationRecord
  belongs_to :recipient, class_name: "User"
  belongs_to :actor, class_name: "User"
  belongs_to :notifiable, polymorphic: true

  enum :notification_type, {
    new_follower: "new_follower",
    review_comment: "review_comment",
    club_post: "club_post",
    buddy_read_invite: "buddy_read_invite",
    buddy_read_message: "buddy_read_message"
  }

  validates :notification_type, presence: true

  scope :unread, -> { where(read_at: nil) }
  scope :recent, -> { order(created_at: :desc) }
  # Notifications not yet included in a digest email, regardless of whether
  # they've since been read in-app — a digest and an in-app read are tracked
  # independently so viewing the bell dropdown doesn't silently skip a
  # notification that would otherwise have been mailed.
  scope :not_yet_digested, -> { where(digested_at: nil) }

  NESTED_NOTIFIABLE_ASSOCIATIONS = {
    "ReviewComment" => {reading: :book},
    "ClubPost" => :club,
    "BuddyRead" => :book,
    "BuddyReadMessage" => {buddy_read: :book}
  }.freeze

  # #message/#target_type reach through notifiable into a further nested
  # association (reading.book, club) that a polymorphic `includes` can't
  # preload in one shot, since different notifiable types don't share an
  # association name. Callers rendering several notifications (inbox, bell
  # dropdown) run this once up front instead of N+1ing per row.
  def self.preload_notifiable_details(notifications)
    notifications = notifications.to_a
    notifications.group_by(&:notifiable_type).each do |type, group|
      associations = NESTED_NOTIFIABLE_ASSOCIATIONS[type]
      next unless associations

      ActiveRecord::Associations::Preloader.new(records: group.map(&:notifiable), associations: associations).call
    end
    notifications
  end

  def read?
    read_at.present?
  end

  def mark_read!
    update!(read_at: Time.current) unless read?
  end

  def message
    case notification_type
    when "new_follower" then "#{actor.display_name} started following you"
    when "review_comment" then "#{actor.display_name} commented on your review of #{notifiable.reading.book.title}"
    when "club_post" then "#{actor.display_name} posted in #{notifiable.club.name}"
    when "buddy_read_invite" then "#{actor.display_name} invited you to a buddy read of #{notifiable.book.title}"
    when "buddy_read_message" then "#{actor.display_name} sent a message in your buddy read of #{notifiable.buddy_read.book.title}"
    end
  end

  # Structured counterpart to NotificationsHelper#notification_path_for, for
  # the JSON API — a client can't follow a Rails path, so it gets a
  # resource type + id instead and builds its own request from that.
  def target_type
    case notification_type
    when "new_follower" then "user"
    when "review_comment" then "reading"
    when "club_post" then "club"
    when "buddy_read_invite" then "buddy_read"
    when "buddy_read_message" then "buddy_read"
    else raise ArgumentError, "Unhandled notification_type: #{notification_type.inspect}"
    end
  end

  def target_id
    case notification_type
    when "new_follower" then actor_id
    when "review_comment" then notifiable.reading_id
    when "club_post" then notifiable.club_id
    when "buddy_read_invite" then notifiable.id
    when "buddy_read_message" then notifiable.buddy_read_id
    else raise ArgumentError, "Unhandled notification_type: #{notification_type.inspect}"
    end
  end
end
