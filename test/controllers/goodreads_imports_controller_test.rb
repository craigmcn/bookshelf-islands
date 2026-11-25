require "test_helper"

# ported from community_bookshelf test/controllers/goodreads_imports_controller_test.rb
class GoodreadsImportsControllerTest < ActionDispatch::IntegrationTest
  test "guest is redirected to sign in" do
    get new_goodreads_import_url
    assert_redirected_to sign_in_path
  end

  test "member can view the import form" do
    sign_in_as users(:member)
    get new_goodreads_import_url
    assert_response :success
  end

  test "member imports new readings from a Goodreads CSV, skipping books already on their shelf" do
    sign_in_as users(:member)
    file = fixture_file_upload("goodreads_export.csv", "text/csv")

    assert_difference "Reading.count", 1 do
      assert_difference "Book.count", 1 do
        post goodreads_import_url, params: {file: file}
      end
    end

    assert_redirected_to readings_url
    assert_match "Imported 1 book", flash[:notice]
    assert_match "Skipped 2 row", flash[:notice]

    imported = Book.find_by(title: "Brave New World")
    reading = users(:member).readings.find_by(book: imported)
    assert_equal "want_to_read", reading.status
    assert_equal "four", reading.rating
  end

  test "member cannot upload a file over the size limit" do
    sign_in_as users(:member)
    oversized = Tempfile.new(["oversized", ".csv"])
    oversized.write("a" * (GoodreadsImportsController::MAX_FILE_BYTES + 1))
    oversized.rewind
    file = Rack::Test::UploadedFile.new(oversized.path, "text/csv")

    assert_no_difference "Reading.count" do
      post goodreads_import_url, params: {file: file}
    end
    assert_redirected_to new_goodreads_import_url
    assert_match "too large", flash[:alert]
  ensure
    oversized&.close!
  end

  test "member must choose a file" do
    sign_in_as users(:member)
    post goodreads_import_url, params: {}
    assert_redirected_to new_goodreads_import_url
    assert_equal "Please choose a CSV file to upload.", flash[:alert]
  end

  test "member submitting a plain string instead of a file is redirected, not errored" do
    sign_in_as users(:member)
    post goodreads_import_url, params: {file: "not-a-file"}
    assert_redirected_to new_goodreads_import_url
    assert_equal "Please choose a CSV file to upload.", flash[:alert]
  end

  test "guest cannot import" do
    file = fixture_file_upload("goodreads_export.csv", "text/csv")
    assert_no_difference "Reading.count" do
      post goodreads_import_url, params: {file: file}
    end
    assert_redirected_to sign_in_path
  end

  test "a malformed CSV is redirected with an alert, not errored" do
    sign_in_as users(:member)
    file = Rack::Test::UploadedFile.new(StringIO.new("Title,Author\n\"unclosed,row\n"), "text/csv", original_filename: "bad.csv")

    assert_no_difference "Reading.count" do
      post goodreads_import_url, params: {file: file}
    end
    assert_redirected_to new_goodreads_import_url
    assert_match "valid CSV", flash[:alert]
  end

  test "a file that isn't a Goodreads export is redirected with an alert" do
    sign_in_as users(:member)
    {fixture_file_upload("avatar.png", "text/csv") => "valid CSV",
     Rack::Test::UploadedFile.new(StringIO.new(""), "text/csv", original_filename: "empty.csv") => "needs Title and Author columns",
     Rack::Test::UploadedFile.new(StringIO.new("title;author\nx;y\n"), "text/csv", original_filename: "semi.csv") => "needs Title and Author columns"}.each do |file, alert|
      assert_no_difference ["Reading.count", "Book.count"] do
        post goodreads_import_url, params: {file: file}
      end
      assert_redirected_to new_goodreads_import_url
      assert_match alert, flash[:alert]
    end
  end
end
