# ported from community_bookshelf app/models/shelf_book.rb
class ShelfBook < ApplicationRecord
  belongs_to :shelf
  belongs_to :book

  validates :book_id, uniqueness: {scope: :shelf_id}
end
