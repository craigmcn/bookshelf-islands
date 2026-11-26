# ported from community_bookshelf app/services/goodreads_import.rb, plus hardening the reference
# lacks (#168): file encodings, ISBN and date validation, per-row error isolation, header check.
require "csv"

# Turns a Goodreads "Export Library" CSV into Readings, matching catalog Books by ISBN, then
# title+author, before creating one. A book already on the shelf (an active Reading) is skipped,
# so re-uploading is a no-op, while one soft-deleted from it is imported afresh.
class GoodreadsImport
  Result = Struct.new(:imported_count, :skipped_count)

  class UnrecognizedFile < StandardError; end

  SHELF_STATUS = {
    "read" => "finished",
    "currently-reading" => "reading",
    "to-read" => "want_to_read"
  }.freeze

  REQUIRED_HEADERS = %w[Title Author].freeze

  # books.page_count is a 4-byte integer, and a bigger value raises on save instead of failing validation
  MAX_PAGE_COUNT = 2**31 - 1

  ISBN_FORMAT = /\A(\d{9}[\dX]|\d{13})\z/
  DATE_FORMAT = %r{\A(\d{4})[/-](\d{1,2})[/-](\d{1,2})\z}

  def initialize(user, csv_content)
    @user = user
    @csv_content = csv_content
  end

  def call
    imported = 0
    skipped = 0

    rows = CSV.parse(normalize_encoding(@csv_content), headers: true, liberal_parsing: true)
    raise UnrecognizedFile unless (REQUIRED_HEADERS - rows.headers).empty?

    rows.each do |row|
      if import_row(row)
        imported += 1
      else
        skipped += 1
      end
    end

    Result.new(imported_count: imported, skipped_count: skipped)
  end

  private

  attr_reader :user

  # A savepoint per row: a row that fails or raises takes its new catalog Book with it, and
  # the rest of the file still imports instead of stopping at a 500 with half of it saved.
  def import_row(row)
    Book.transaction(requires_new: true) do
      book = find_or_create_book(row)
      # Default scope: a soft-deleted Reading doesn't count as "already on your shelf".
      next false if book.nil? || Reading.exists?(user: user, book: book)

      reading = Reading.new(user: user, book: book)
      apply_row(reading, row)
      reading.save || raise(ActiveRecord::Rollback)
    end
  rescue ActiveRecord::ActiveRecordError, ActiveModel::RangeError, RangeError => error
    Rails.logger.warn("GoodreadsImport: skipped a row after #{error.class}")
    false
  end

  # Uploads arrive as binary. Excel saves "Unicode Text" as UTF-16 with a BOM and plain CSV as
  # Windows-1252, so decode those rather than scrub them into garbage titles in the shared catalog.
  def normalize_encoding(content)
    content = content.b
    text = if content.start_with?("\xFF\xFE".b) || content.start_with?("\xFE\xFF".b)
      encoding = content.start_with?("\xFF\xFE".b) ? Encoding::UTF_16LE : Encoding::UTF_16BE
      content.byteslice(2..).force_encoding(encoding).encode(Encoding::UTF_8, invalid: :replace, undef: :replace)
    else
      content = content.byteslice(3..) if content.start_with?("\xEF\xBB\xBF".b)
      utf8 = content.dup.force_encoding(Encoding::UTF_8)
      utf8.valid_encoding? ? utf8 : content.force_encoding(Encoding::WINDOWS_1252).encode(Encoding::UTF_8, invalid: :replace, undef: :replace)
    end

    # NULs in the header mean BOM-less UTF-16; anywhere else Postgres can't store them, and
    # NullByteGuard skips uploaded files, so they're stripped here.
    raise UnrecognizedFile if text[/\A[^\n]*/].include?("\0")
    text.delete("\0")
  end

  def find_or_create_book(row)
    title = row["Title"].to_s.strip
    author = row["Author"].to_s.strip
    return nil if title.blank? || author.blank?

    isbns = [clean_isbn(row["ISBN13"]), clean_isbn(row["ISBN"])].compact
    book = Book.where(isbn: isbns).order(:id).first if isbns.any?
    # lower() on both sides: Ruby's downcase and Postgres' lower() disagree on e.g. "İ"
    book ||= Book.where("lower(title) = lower(?) AND lower(author) = lower(?)", title, author).order(:id).first
    return book if book

    book = Book.new(title: title, author: author, isbn: isbns.first, page_count: parse_page_count(row["Number of Pages"]), added_by: user)
    book.save ? book : nil
  end

  # Goodreads wraps ISBNs as ="..."; Excel re-saves can leave "9.78074E+12" or "N/A",
  # which would otherwise match every other book sharing the same junk value.
  def clean_isbn(raw)
    isbn = raw.to_s.delete('-=" ').upcase
    isbn if isbn.match?(ISBN_FORMAT)
  end

  def parse_page_count(raw)
    pages = raw.to_s.strip.to_i
    pages.between?(1, MAX_PAGE_COUNT) ? pages : nil
  end

  def apply_row(reading, row)
    reading.skip_activity_logging = true
    reading.status = SHELF_STATUS.fetch(row["Exclusive Shelf"].to_s.strip, "want_to_read")

    my_rating = row["My Rating"].to_s.strip.to_i
    reading.rating = my_rating if my_rating.between?(1, 5)

    reading.review = row["My Review"].presence
    reading.finished_on = parse_date(row["Date Read"])
  end

  # Goodreads writes YYYY/MM/DD. Date.parse would also accept "5/12/23" or "maybe" and
  # record a confidently wrong date, so anything else is left blank.
  def parse_date(raw)
    year, month, day = raw.to_s.strip.match(DATE_FORMAT)&.captures&.map(&:to_i)
    Date.new(year, month, day) if year&.between?(1, 9999) # Postgres has no year 0
  rescue Date::Error
    nil
  end
end
