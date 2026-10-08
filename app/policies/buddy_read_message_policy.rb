# ported from community_bookshelf app/policies/buddy_read_message_policy.rb
# Only create? — messages are never individually viewed/edited outside the
# parent buddy read's show page.
class BuddyReadMessagePolicy < ApplicationPolicy
  def create? = record.buddy_read.participant?(user) && record.buddy_read.messageable?
end
