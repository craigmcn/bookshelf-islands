# ported from community_bookshelf app/models/buddy_read_message.rb
class BuddyReadMessage < ApplicationRecord
  belongs_to :buddy_read
  belongs_to :user

  validates :body, presence: true, length: {maximum: 1000}
end
