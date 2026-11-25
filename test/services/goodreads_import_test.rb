require "test_helper"

# ported from community_bookshelf test/services/goodreads_import_test.rb
class GoodreadsImportTest < ActiveSupport::TestCase
  test "creates a book and reading for a new title, matching status and rating" do
    csv = <<~CSV
      Title,Author,ISBN,ISBN13,My Rating,Number of Pages,Year Published,Date Read,My Review,Exclusive Shelf
      Dune,Frank Herbert,="0441013597",="9780441013593",5,412,1965,2024/01/20,Loved it.,read
    CSV

    result = GoodreadsImport.new(users(:member), csv).call

    assert_equal 1, result.imported_count
    assert_equal 0, result.skipped_count

    book = Book.find_by!(title: "Dune", author: "Frank Herbert")
    assert_equal "9780441013593", book.isbn
    assert_equal 412, book.page_count

    reading = users(:member).readings.find_by!(book: book)
    assert_equal "finished", reading.status
    assert_equal "five", reading.rating
    assert_equal "Loved it.", reading.review
    assert_equal Date.new(2024, 1, 20), reading.finished_on
  end

  test "matches an existing book by ISBN instead of creating a duplicate" do
    existing = books(:one)
    existing.update!(isbn: "9780743273565")

    csv = <<~CSV
      Title,Author,ISBN,ISBN13,My Rating,Number of Pages,Year Published,Date Read,My Review,Exclusive Shelf
      A Different Title,Someone Else,,="9780743273565",4,,,,to-read
    CSV

    assert_no_difference "Book.count" do
      GoodreadsImport.new(users(:moderator), csv).call
    end

    reading = users(:moderator).readings.find_by!(book: existing)
    assert_equal "want_to_read", reading.status
  end

  test "skips rows for books the user already has on their shelf" do
    reading = readings(:one)

    csv = <<~CSV
      Title,Author,ISBN,ISBN13,My Rating,Number of Pages,Year Published,Date Read,My Review,Exclusive Shelf
      #{reading.book.title},#{reading.book.author},,,3,,,,,read
    CSV

    result = GoodreadsImport.new(reading.user, csv).call

    assert_equal 0, result.imported_count
    assert_equal 1, result.skipped_count
  end

  test "re-imports a book whose reading was soft-deleted from the shelf" do
    reading = readings(:one)
    reading.soft_delete

    csv = <<~CSV
      Title,Author,ISBN,ISBN13,My Rating,Number of Pages,Year Published,Date Read,My Review,Exclusive Shelf
      #{reading.book.title},#{reading.book.author},,,3,,,,,read
    CSV

    result = GoodreadsImport.new(reading.user, csv).call

    assert_equal 1, result.imported_count
    assert_equal 0, result.skipped_count

    new_reading = reading.user.readings.find_by!(book: reading.book)
    assert_not_equal reading.id, new_reading.id
  end

  test "skips rows missing a title or author" do
    csv = <<~CSV
      Title,Author,ISBN,ISBN13,My Rating,Number of Pages,Year Published,Date Read,My Review,Exclusive Shelf
      ,,,,,,,,,
    CSV

    result = GoodreadsImport.new(users(:member), csv).call

    assert_equal 0, result.imported_count
    assert_equal 1, result.skipped_count
  end

  test "defaults to want_to_read when the shelf column is missing or unrecognized" do
    csv = <<~CSV
      Title,Author,ISBN,ISBN13,My Rating,Number of Pages,Year Published,Date Read,My Review,Exclusive Shelf
      Some Book,Some Author,,,,,,,,some-custom-shelf
    CSV

    GoodreadsImport.new(users(:member), csv).call

    reading = users(:member).readings.find_by!(book: Book.find_by!(title: "Some Book"))
    assert_equal "want_to_read", reading.status
  end

  test "handles a binary-encoded upload with a UTF-8 BOM and non-ASCII characters without raising" do
    csv = <<~CSV
      Title,Author,ISBN,ISBN13,My Rating,Number of Pages,Year Published,Date Read,My Review,Exclusive Shelf
      Café de Flore,José Something,,,4,,,,,read
    CSV
    binary_content = ("\xEF\xBB\xBF" + csv).dup.force_encoding(Encoding::BINARY)

    result = GoodreadsImport.new(users(:member), binary_content).call

    assert_equal 1, result.imported_count
    assert Book.exists?(title: "Café de Flore")
  end

  test "does not create activity-feed entries for imported readings" do
    csv = <<~CSV
      Title,Author,ISBN,ISBN13,My Rating,Number of Pages,Year Published,Date Read,My Review,Exclusive Shelf
      Dune,Frank Herbert,,,5,,,,,read
    CSV

    assert_no_difference "Activity.count" do
      GoodreadsImport.new(users(:member), csv).call
    end
  end

  HEADERS = "Title,Author,ISBN,ISBN13,My Rating,Number of Pages,Year Published,Date Read,My Review,Exclusive Shelf\n"

  # NullByteGuard skips uploaded files, so this is the only thing between a NUL and Postgres
  test "strips NUL bytes rather than raising" do
    result = GoodreadsImport.new(users(:member), HEADERS + "Du\0ne,Frank Herbert,,,5,,,,Lo\0ved it.,read\n").call

    assert_equal 1, result.imported_count
    assert_equal "Loved it.", users(:member).readings.find_by!(book: Book.find_by!(title: "Dune")).review
  end

  test "drops a page count too big for the column rather than raising" do
    result = GoodreadsImport.new(users(:member), HEADERS + "Dune,Frank Herbert,,,5,99999999999,,,,read\n").call

    assert_equal 1, result.imported_count
    assert_nil Book.find_by!(title: "Dune").page_count
  end

  test "drops a read date Postgres can't store rather than raising" do
    result = GoodreadsImport.new(users(:member), HEADERS + "Dune,Frank Herbert,,,5,,,9999999-01-01,,read\n").call

    assert_equal 1, result.imported_count
    assert_nil users(:member).readings.find_by!(book: Book.find_by!(title: "Dune")).finished_on
  end

  test "a row repeated within one file is imported once" do
    result = GoodreadsImport.new(users(:member), HEADERS + "Dune,Frank Herbert,,,5,,,,,read\n" * 2).call

    assert_equal [1, 1], [result.imported_count, result.skipped_count]
  end

  test "still awards badges" do
    assert_difference -> { users(:member).user_badges.where(badge_key: "books_finished_1").count }, 1 do
      GoodreadsImport.new(users(:member), HEADERS + "Dune,Frank Herbert,,,5,,,,,read\n").call
    end
  end
end
