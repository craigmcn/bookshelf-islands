require "test_helper"

class ReadingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @reading = readings(:one)
  end

  test "guest is redirected to sign in" do
    get readings_url
    assert_redirected_to sign_in_path
  end

  test "member can view their readings" do
    sign_in_as users(:member)
    get readings_url
    assert_response :success
  end

  # Search, filter, sort, pagination (JSON API backing the ShelfBrowser island)
  test "shelf json filters by title or author" do
    sign_in_as users(:member)
    Reading.create!(user: users(:member), book: books(:two), status: :reading)

    get readings_url(q: "1984", format: :json)
    assert_response :success
    readings = JSON.parse(response.body)["readings"]
    assert_equal ["1984"], readings.pluck("book_title")
  end

  test "shelf json filters by status" do
    sign_in_as users(:member)
    Reading.create!(user: users(:member), book: books(:two), status: :finished)

    get readings_url(status: "finished", format: :json)
    readings = JSON.parse(response.body)["readings"]
    assert_equal ["1984"], readings.pluck("book_title")
  end

  test "shelf json filters by rating" do
    sign_in_as users(:member)
    Reading.create!(user: users(:member), book: books(:two), status: :finished, rating: :two)

    get readings_url(rating: "four", format: :json)
    readings = JSON.parse(response.body)["readings"]
    assert_equal ["The Great Gatsby"], readings.pluck("book_title")
  end

  test "shelf json only includes the current user's readings" do
    sign_in_as users(:member)
    Reading.create!(user: users(:admin), book: books(:two), status: :reading)

    get readings_url(format: :json)
    readings = JSON.parse(response.body)["readings"]
    assert_equal ["The Great Gatsby"], readings.pluck("book_title")
  end

  test "shelf json ignores an unknown status or rating filter" do
    sign_in_as users(:member)
    get readings_url(status: "bogus", rating: "bogus", format: :json)
    readings = JSON.parse(response.body)["readings"]
    assert_equal ["The Great Gatsby"], readings.pluck("book_title")
  end

  test "member can create a reading" do
    sign_in_as users(:member)
    assert_difference "Reading.count" do
      post readings_url, params: {reading: {book_id: books(:two).id, status: :reading}}
    end
    assert_redirected_to reading_url(Reading.last)
  end

  test "member can start a re-read via JSON (re-read island)" do
    sign_in_as users(:member)
    @reading.update!(status: :finished)

    assert_difference "Reading.count" do
      post readings_url, params: {reading: {book_id: @reading.book_id, status: "want_to_read"}}, as: :json
    end

    assert_response :created
    body = JSON.parse(response.body)
    assert_equal Reading.last.id, body["id"]
    assert_equal "want_to_read", body["status"]
    assert_equal @reading.book_id, body["book_id"]
  end

  test "starting a re-read does not require the earlier reading to be removed" do
    sign_in_as users(:member)
    @reading.update!(status: :finished)

    post readings_url, params: {reading: {book_id: @reading.book_id, status: "want_to_read"}}, as: :json

    assert_equal 2, Reading.where(user: users(:member), book: @reading.book).count
  end

  test "member can update their own reading" do
    sign_in_as users(:member)
    patch reading_url(@reading), params: {reading: {status: :finished, book_id: @reading.book_id}}
    assert_redirected_to reading_url(@reading)
    assert_equal "finished", @reading.reload.status
  end

  test "member cannot destroy a reading" do
    sign_in_as users(:member)
    assert_no_difference "Reading.count" do
      delete reading_url(@reading)
    end
    assert_nil @reading.reload.deleted_at
  end

  test "moderator can soft-delete a reading" do
    sign_in_as users(:moderator)
    assert_no_difference "Reading.unscoped.count" do
      delete reading_url(@reading)
    end
    assert_redirected_to readings_url
    assert_not_nil @reading.reload.deleted_at
  end

  test "moderator can soft-delete a reading via JSON (admin moderation island)" do
    sign_in_as users(:moderator)
    assert_no_difference "Reading.unscoped.count" do
      delete reading_url(@reading), as: :json
    end
    assert_response :no_content
    assert_not_nil @reading.reload.deleted_at
  end
end
