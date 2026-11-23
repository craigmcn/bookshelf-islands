require "test_helper"

class ReviewLikesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @reading = Reading.create!(user: users(:member), book: books(:two), status: :finished, review: "Great.")
  end

  test "guest is redirected to sign in" do
    post reading_review_like_url(@reading)
    assert_redirected_to sign_in_path
  end

  test "member can like another member's public review" do
    sign_in_as users(:moderator)
    post reading_review_like_url(@reading)

    assert_redirected_to reading_url(@reading)
    assert @reading.review_likes.exists?(user: users(:moderator))
  end

  test "member cannot like a private review" do
    @reading.update!(is_review_public: false)
    sign_in_as users(:moderator)

    post reading_review_like_url(@reading)

    assert_not @reading.review_likes.exists?(user: users(:moderator))
  end

  test "a denied JSON like is a 403, not a redirect to an HTML page (#158)" do
    @reading.update!(is_review_public: false)
    sign_in_as users(:moderator)

    post reading_review_like_url(@reading), as: :json

    assert_response :forbidden
    assert_equal "You are not authorized to perform this action.", response.parsed_body["error"]
    assert_not @reading.review_likes.exists?(user: users(:moderator))
  end

  test "liking twice does not raise and leaves a single like" do
    sign_in_as users(:moderator)
    post reading_review_like_url(@reading)
    post reading_review_like_url(@reading)

    assert_equal 1, @reading.review_likes.where(user: users(:moderator)).count
  end

  test "member can unlike" do
    ReviewLike.create!(user: users(:moderator), reading: @reading)
    sign_in_as users(:moderator)

    delete reading_review_like_url(@reading)

    assert_redirected_to reading_url(@reading)
    assert_not @reading.review_likes.exists?(user: users(:moderator))
  end

  test "unliking twice is idempotent" do
    sign_in_as users(:moderator)

    delete reading_review_like_url(@reading)
    delete reading_review_like_url(@reading)

    assert_not @reading.review_likes.exists?(user: users(:moderator))
  end

  test "create responds with JSON like state for the island" do
    sign_in_as users(:moderator)
    post reading_review_like_url(@reading), as: :json

    assert_response :success
    body = response.parsed_body
    assert body["liked"]
    assert_equal 1, body["count"]
  end

  test "destroy responds with JSON like state for the island" do
    ReviewLike.create!(user: users(:moderator), reading: @reading)
    sign_in_as users(:moderator)

    delete reading_review_like_url(@reading), as: :json

    assert_response :success
    body = response.parsed_body
    assert_not body["liked"]
    assert_equal 0, body["count"]
  end
end
