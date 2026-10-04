# ported from community_bookshelf app/models/favorite_genre.rb
class FavoriteGenre < ApplicationRecord
  belongs_to :user
  belongs_to :tag

  validates :tag_id, uniqueness: {scope: :user_id}
end
