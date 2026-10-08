# ported from community_bookshelf app/models/buddy_read.rb, plus a
# buddy_read_invite Notification on create — the reference implementation
# doesn't send one, leaving an invite discoverable only by visiting the
# index (see community_bookshelf#199, filed to bring it in line with this).
class BuddyRead < ApplicationRecord
  belongs_to :book
  belongs_to :initiator, class_name: "User"
  belongs_to :partner, class_name: "User"
  has_many :messages, class_name: "BuddyReadMessage", dependent: :destroy
  has_one :notification, as: :notifiable, dependent: :destroy

  enum :status, {pending: "pending", accepted: "accepted", declined: "declined", cancelled: "cancelled", completed: "completed"}, default: "pending"

  validate :initiator_and_partner_are_distinct

  after_create :notify_partner

  def participant?(user)
    user && (initiator_id == user.id || partner_id == user.id)
  end

  def other_participant(user)
    (user.id == initiator_id) ? partner : initiator
  end

  # Declining or cancelling ends the pairing — a thread with no active or
  # completed relationship behind it shouldn't keep accepting new messages.
  def messageable?
    !declined? && !cancelled?
  end

  private

  def initiator_and_partner_are_distinct
    errors.add(:partner_id, "can't be yourself") if initiator_id.present? && initiator_id == partner_id
  end

  def notify_partner
    Notification.create!(recipient: partner, actor: initiator, notifiable: self, notification_type: :buddy_read_invite)
  end
end
