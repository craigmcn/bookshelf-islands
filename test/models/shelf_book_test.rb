require "test_helper"

class ShelfBookTest < ActiveSupport::TestCase
  test "valid with a shelf and book" do
    assert ShelfBook.new(shelf: shelves(:one), book: books(:one)).valid?
  end

  test "invalid with a duplicate book on the same shelf" do
    ShelfBook.create!(shelf: shelves(:one), book: books(:one))
    assert_not ShelfBook.new(shelf: shelves(:one), book: books(:one)).valid?
  end

  test "valid with the same book on a different shelf" do
    ShelfBook.create!(shelf: shelves(:one), book: books(:one))
    other_shelf = Shelf.create!(user: shelves(:one).user, name: "Another List")
    assert ShelfBook.new(shelf: other_shelf, book: books(:one)).valid?
  end
end
