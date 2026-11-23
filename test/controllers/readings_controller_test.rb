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

  # adapted from community_bookshelf test/controllers/readings_controller_test.rb (community_bookshelf#242)
  test "shelf treats an array or hash search param as no search" do
    sign_in_as users(:member)
    get readings_url(q: ["nothing-matches-this"], format: :json)
    assert_response :success
    assert_equal [@reading.id], JSON.parse(response.body)["readings"].pluck("id")

    get readings_url(q: {k: "nothing-matches-this"}, format: :json)
    assert_equal [@reading.id], JSON.parse(response.body)["readings"].pluck("id")

    get readings_url(q: ["nothing-matches-this"])
    assert_response :success
    assert_select "[data-shelf-browser-query-value=?]", ""
  end

  test "noscript shelf treats an array search param as no filter" do
    sign_in_as users(:admin) # no readings of their own
    get readings_url(q: ["nothing-matches-this"])
    assert_select "noscript", text: /Your shelf is empty\./
    assert_select "noscript", text: /No readings match those filters\./, count: 0
  end

  test "shelf renders, unfiltered, when status, rating or sort is a hash" do
    sign_in_as users(:member)
    [{status: {k: "x"}}, {rating: {k: "x"}}, {sort: {k: "x"}}].each do |params|
      get readings_url(params) # tag chips render with the fixtures, so every link helper runs
      assert_response :success
      assert_select "a[href*=?]", "/readings?", minimum: 1
    end
    assert_select "[data-shelf-browser-status-value=?]", ""
    assert_select "[data-shelf-browser-rating-value=?]", ""
  end

  test "shelf echoes only a valid status and rating" do
    sign_in_as users(:member)
    get readings_url(status: ["finished"], rating: "four")
    assert_select "[data-shelf-browser-status-value=?]", ""
    assert_select "[data-shelf-browser-rating-value=?]", "four"
    assert_select "select[name=rating] option[selected][value=?]", "four"
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

  test "shelf json filters by genre tag" do
    sign_in_as users(:member)
    Reading.create!(user: users(:member), book: books(:two), status: :reading)

    get readings_url(tag: tags(:one).name, format: :json) # books(:one) is tagged fantasy via the taggings fixture
    body = JSON.parse(response.body)
    assert_equal ["The Great Gatsby"], body["readings"].pluck("book_title")
    assert_equal tags(:one).name, body["tag"]
  end

  test "shelf json returns no readings for an unknown tag" do
    sign_in_as users(:member)
    get readings_url(tag: "no-such-tag", format: :json)
    body = JSON.parse(response.body)
    assert_empty body["readings"]
    assert_nil body["tag"]
  end

  test "shelf json includes the genre tags present on the user's shelf" do
    sign_in_as users(:member)
    get readings_url(format: :json)
    body = JSON.parse(response.body)
    assert_equal [tags(:one).name], body["shelf_tags"].pluck("name")
  end

  test "shelf index renders recommended books tagged like ones the user rated highly" do
    sign_in_as users(:member) # readings(:one) rates books(:one) (tagged fantasy) a 4, which counts as "liked"
    recommended = Book.create!(title: "Recommended Fantasy", author: "A. Uthor", added_by: users(:admin), tag_list: "fantasy")

    get readings_url
    assert_response :success
    assert_match(/Recommended Fantasy/, response.body)
    assert_equal [recommended], Book.recommended_for(users(:member))
  end

  test "member can create a reading" do
    sign_in_as users(:member)
    assert_difference "Reading.count" do
      post readings_url, params: {reading: {book_id: books(:two).id, status: :reading}}
    end
    assert_redirected_to reading_url(Reading.last)
  end

  test "owner can view their own reading regardless of review privacy" do
    sign_in_as users(:member)
    @reading.update!(is_review_public: false)

    get reading_url(@reading)
    assert_response :success
  end

  test "another member can view a public review" do
    other = User.create!(email: "other@example.com", password: User::DEFAULT_PASSWORD)
    sign_in_as other

    get reading_url(@reading) # readings(:one) has a public review, owned by member
    assert_response :success
  end

  test "another member cannot view a private review" do
    @reading.update!(is_review_public: false)
    other = User.create!(email: "other@example.com", password: User::DEFAULT_PASSWORD)
    sign_in_as other

    get reading_url(@reading)
    assert_redirected_to root_url
  end

  test "moderator can view a private review" do
    @reading.update!(is_review_public: false)
    sign_in_as users(:moderator)

    get reading_url(@reading)
    assert_response :success
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

  test "member can set tracking fields when creating a reading" do
    sign_in_as users(:member)
    post readings_url, params: {reading: {
      book_id: books(:two).id, status: :reading, format: :ebook,
      started_on: "2026-01-05", progress_percent: 42, is_review_public: "false"
    }}

    reading = Reading.last
    assert_equal "ebook", reading.format
    assert_equal Date.new(2026, 1, 5), reading.started_on
    assert_equal 42, reading.progress_percent
    assert_not reading.is_review_public?
  end

  test "member can mark a reading as DNF" do
    sign_in_as users(:member)
    patch reading_url(@reading), params: {reading: {status: :dnf, book_id: @reading.book_id}}
    assert_equal "dnf", @reading.reload.status
  end

  test "shelf json includes progress_percent" do
    sign_in_as users(:member)
    @reading.update!(progress_percent: 60)

    get readings_url(format: :json)
    body = JSON.parse(response.body)
    reading_json = body["readings"].find { |r| r["id"] == @reading.id }
    assert_equal 60, reading_json["progress_percent"]
  end

  # ported from community_bookshelf test/controllers/readings_controller_test.rb
  test "member can soft-delete their own reading" do
    sign_in_as users(:member)
    assert_no_difference "Reading.unscoped.count" do
      delete reading_url(@reading)
    end
    assert_redirected_to readings_url
    assert_not_nil @reading.reload.deleted_at
  end

  test "member can soft-delete their own reading via JSON (shelf island)" do
    sign_in_as users(:member)
    delete reading_url(@reading), as: :json
    assert_response :no_content
    assert_not_nil @reading.reload.deleted_at
  end

  test "member cannot destroy another member's reading" do
    other = Reading.create!(user: users(:moderator), book: books(:two), status: :reading)
    sign_in_as users(:member)
    delete reading_url(other)
    assert_redirected_to root_url
    assert_nil other.reload.deleted_at
  end

  test "a denied JSON reading delete is a 403 (#158)" do
    other = Reading.create!(user: users(:moderator), book: books(:two), status: :reading)
    sign_in_as users(:member)
    delete reading_url(other), as: :json
    assert_response :forbidden
    assert_nil other.reload.deleted_at
  end

  test "shelf offers its owner a remove control" do
    sign_in_as users(:member)
    get readings_url(format: :json)
    reading_json = JSON.parse(response.body)["readings"].find { |r| r["id"] == @reading.id }
    assert reading_json["can_destroy"]

    # the <noscript> fallback row renders the same control as a plain form
    get readings_url
    assert_select "form[action=?] .visually-hidden", reading_path(@reading), text: "Remove reading"
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

  test "noscript shelf distinguishes an empty shelf from a filter with no matches" do
    sign_in_as users(:admin) # no readings of their own
    get readings_url
    assert_select "noscript", text: /Your shelf is empty\./

    get readings_url(q: "nonexistent title")
    assert_select "noscript", text: /No readings match those filters\./
  end

  test "noscript shelf shows the empty-shelf state when only invalid filters are given" do
    sign_in_as users(:admin) # no readings of their own
    get readings_url(status: "bogus", rating: "bogus")
    assert_select "noscript", text: /Your shelf is empty\./
    assert_select "noscript", text: /No readings match those filters\./, count: 0
  end

  # ported from community_bookshelf test/controllers/readings_controller_test.rb (community_bookshelf#218)
  test "shelf json rating sort puts rated readings before unrated ones" do
    unrated = Reading.create!(user: users(:member), book: books(:two), status: :want_to_read)
    rated = readings(:one) # rated

    sign_in_as users(:member)
    get readings_url(sort: "rating", format: :json)

    ids = JSON.parse(response.body)["readings"].pluck("id")
    assert_operator ids.index(rated.id), :<, ids.index(unrated.id)
  end

  # ported from community_bookshelf test/controllers/readings_controller_test.rb (community_bookshelf#218)
  test "shelf json breaks sort ties by newest id, so paging is stable" do
    # Both unrated, so the rating sort ties; without a tiebreaker Postgres returns them in insertion order.
    older = Reading.create!(user: users(:member), book: books(:two), status: :want_to_read)
    newer = Reading.create!(user: users(:member), book: books(:two), status: :want_to_read)

    sign_in_as users(:member)
    get readings_url(sort: "rating", format: :json)

    assert_equal [readings(:one).id, newer.id, older.id], JSON.parse(response.body)["readings"].pluck("id")
  end
end
