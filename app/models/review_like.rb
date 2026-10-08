# ported from community_bookshelf app/models/review_like.rb
class ReviewLike < ApplicationRecord
  belongs_to :user
  belongs_to :reading

  validates :user_id, uniqueness: {scope: :reading_id}
end
