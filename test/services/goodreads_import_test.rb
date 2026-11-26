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
    result = GoodreadsImport.new(users(:member), HEADERS + "Dune,Frank Herbert,,,5,,,2024/9999999999/1,,read\n").call

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

  def import(rows, user = users(:member)) = GoodreadsImport.new(user, HEADERS + rows).call

  def reading_for(title, user = users(:member)) = user.readings.find_by!(book: Book.find_by!(title: title))

  test "a row that raises is skipped, taking its new book with it, and later rows still import" do
    import = GoodreadsImport.new(users(:member), HEADERS + "First,A,,,,,,,,read\nBoom,A,,,,,,,,read\nLast,A,,,,,,,,read\n")
    apply_row = import.method(:apply_row)
    import.define_singleton_method(:apply_row) do |reading, row|
      raise ActiveRecord::StatementInvalid, "boom" if row["Title"] == "Boom"
      apply_row.call(reading, row)
    end

    assert_equal [2, 1], import.call.to_a
    assert_not Book.exists?(title: "Boom")
  end

  test "a row whose reading fails validation leaves no orphan book" do
    import = GoodreadsImport.new(users(:member), HEADERS + "Orphan,A,,,,,,,,read\n")
    import.define_singleton_method(:apply_row) { |reading, _row| reading.progress_percent = 101 }

    assert_equal [0, 1], import.call.to_a
    assert_not Book.exists?(title: "Orphan")
  end

  [["UTF-16LE", "\xFF\xFE"], ["UTF-16BE", "\xFE\xFF"]].each do |encoding, bom|
    test "decodes a #{encoding} file with a BOM" do
      csv = "Book Id,Title,Author,My Rating,Exclusive Shelf\n1,Café Łódź,José,4,read\n"
      assert_equal [1, 0], GoodreadsImport.new(users(:member), bom.b + csv.encode(encoding).b).call.to_a
      assert Book.exists?(title: "Café Łódź", author: "José")
    end
  end

  test "rejects BOM-less UTF-16 instead of stripping its NULs into a matching header" do
    csv = "Title,Author\nDune,Frank Herbert\n".encode("UTF-16LE").b
    assert_raises(GoodreadsImport::UnrecognizedFile) { GoodreadsImport.new(users(:member), csv).call }
  end

  test "decodes a Windows-1252 file, as Excel saves plain CSV" do
    csv = (HEADERS + "Ender’s Café,Orson Scott Card,,,,,,,,read\n").encode("Windows-1252").b
    assert_equal [1, 0], GoodreadsImport.new(users(:member), csv).call.to_a
    assert Book.exists?(title: "Ender’s Café")
  end

  test "rejects a file without Title and Author columns" do
    ["", "title;author\nx;y\n", "Book Id,Authors\n1,x\n"].each do |content|
      assert_raises(GoodreadsImport::UnrecognizedFile, content) { GoodreadsImport.new(users(:member), content).call }
    end
  end

  test "an ISBN Excel mangled into scientific notation, or a placeholder, matches nothing" do
    books(:two).update!(isbn: "9.78074E+12")
    assert_equal [3, 0], import("Book A,A,,9.78074E+12,,,,,,read\nBook B,B,,9.78074E+12,,,,,,read\nBook C,C,N/A,,,,,,,read\n").to_a
    assert_nil Book.find_by!(title: "Book A").isbn
  end

  test "falls back to the ISBN10 when Goodreads leaves ISBN13 as an empty =\"\"" do
    books(:two).update!(isbn: "0441013597")
    assert_no_difference("Book.count") { import(%(Dune,Frank Herbert,="0441013597",="",,,,,,read\n)) }
    assert reading_for(books(:two).title)
  end

  test "matches a catalog book stored under its ISBN10 when the row has both" do
    books(:two).update!(isbn: "0441013597")
    assert_no_difference("Book.count") { import(%(Dune,Frank Herbert,="0441013597",="9780441013593",,,,,,read\n)) }
  end

  test "normalizes a hyphenated ISBN" do
    import("Dune,Frank Herbert,,978-0-441-01359-3,,,,,,read\n")
    assert_equal "9780441013593", Book.find_by!(title: "Dune").isbn
  end

  test "matches title and author case-insensitively, the same way Postgres does" do
    assert_no_difference("Book.count") { import("#{books(:two).title.upcase},#{books(:two).author.downcase},,,,,,,,read\n") }
    2.times { import("İstanbul,Orhan Pamuk,,,,,,,,read\n") }
    assert_equal 1, Book.where(title: "İstanbul").count
    assert_equal 1, users(:member).readings.joins(:book).where(books: {title: "İstanbul"}).count
  end

  test "a matching title by a different author is a different book" do
    assert_difference("Book.count", 1) { import("#{books(:two).title},Someone Else,,,,,,,,read\n") }
  end

  test "parses only Goodreads' YYYY/MM/DD dates, leaving anything else blank" do
    {"2023/05/12" => Date.new(2023, 5, 12), "2023-5-2" => Date.new(2023, 5, 2), "5/12/23" => nil,
     "5/12/2023" => nil, "maybe" => nil, "2023/02/30" => nil, "0000/01/01" => nil, "2023/05/12 extra" => nil}.each_with_index do |(raw, expected), i|
      import("Date #{i},A,,,,,,#{raw},,read\n")
      finished_on = reading_for("Date #{i}").finished_on
      expected ? assert_equal(expected, finished_on, raw) : assert_nil(finished_on, raw)
    end
  end

  test "maps currently-reading, ignores ratings outside 1-5 and blanks an empty review" do
    import("Now,A,,,6,,,,  ,currently-reading\nZero,A,,,0,,,,,read\n")
    assert_equal ["reading", nil, nil], reading_for("Now").then { [it.status, it.rating, it.review] }
    assert_nil reading_for("Zero").rating
  end
end
