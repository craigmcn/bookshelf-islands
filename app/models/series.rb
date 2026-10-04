# ported from community_bookshelf app/models/series.rb
class Series < ApplicationRecord
  has_many :books, dependent: :nullify

  validates :name, presence: true, uniqueness: true
end
