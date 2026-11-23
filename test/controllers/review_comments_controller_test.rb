require "test_helper"

class ReviewCommentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @reading = Reading.create!(user: users(:member), book: books(:two), status: :finished, review: "Great.")
  end

  test "guest is redirected to sign in" do
    post reading_review_comments_url(@reading), params: {review_comment: {body: "Nice!"}}
    assert_redirected_to sign_in_path
  end

  test "member can comment on another member's public review" do
    sign_in_as users(:moderator)
    post reading_review_comments_url(@reading), params: {review_comment: {body: "Nice!"}}

    assert_redirected_to reading_url(@reading)
    assert_equal ["Nice!"], @reading.review_comments.pluck(:body)
  end

  test "member cannot comment on a private review" do
    @reading.update!(is_review_public: false)
    sign_in_as users(:moderator)

    post reading_review_comments_url(@reading), params: {review_comment: {body: "Nice!"}}

    assert_redirected_to root_url
    assert_empty @reading.review_comments
  end

  test "a denied JSON comment is a 403, not a redirect to an HTML page (#158)" do
    @reading.update!(is_review_public: false)
    sign_in_as users(:moderator)

    post reading_review_comments_url(@reading), params: {review_comment: {body: "Nice!"}}, as: :json

    assert_response :forbidden
    assert_equal "You are not authorized to perform this action.", response.parsed_body["error"]
    assert_empty @reading.review_comments
  end

  test "comment author can delete their own comment" do
    comment = ReviewComment.create!(user: users(:moderator), reading: @reading, body: "Nice!")
    sign_in_as users(:moderator)

    delete reading_review_comment_url(@reading, comment)

    assert_redirected_to reading_url(@reading)
    assert_not ReviewComment.exists?(comment.id)
  end

  test "another member cannot delete someone else's comment" do
    comment = ReviewComment.create!(user: users(:moderator), reading: @reading, body: "Nice!")
    other = User.create!(email: "other@example.com", password: User::DEFAULT_PASSWORD)
    sign_in_as other

    delete reading_review_comment_url(@reading, comment)

    assert_redirected_to root_url
    assert ReviewComment.exists?(comment.id)
  end

  test "a denied JSON comment delete is a 403 (#158)" do
    comment = ReviewComment.create!(user: users(:moderator), reading: @reading, body: "Nice!")
    other = User.create!(email: "other@example.com", password: User::DEFAULT_PASSWORD)
    sign_in_as other

    delete reading_review_comment_url(@reading, comment), as: :json

    assert_response :forbidden
    assert ReviewComment.exists?(comment.id)
  end

  test "moderator can delete another member's comment" do
    comment = ReviewComment.create!(user: users(:member), reading: @reading, body: "Thanks for the rec!")
    sign_in_as users(:admin)

    delete reading_review_comment_url(@reading, comment)

    assert_redirected_to reading_url(@reading)
    assert_not ReviewComment.exists?(comment.id)
  end

  test "create responds with JSON comment payload for the island" do
    sign_in_as users(:moderator)
    post reading_review_comments_url(@reading), params: {review_comment: {body: "Nice!"}}, as: :json

    assert_response :created
    body = response.parsed_body
    assert_equal "Nice!", body["body"]
    assert_equal users(:moderator).display_name, body["author_name"]
  end

  test "create responds with JSON errors when the body is blank" do
    sign_in_as users(:moderator)
    post reading_review_comments_url(@reading), params: {review_comment: {body: ""}}, as: :json

    assert_response :unprocessable_content
  end

  test "destroy responds with no content for the island" do
    comment = ReviewComment.create!(user: users(:moderator), reading: @reading, body: "Nice!")
    sign_in_as users(:moderator)

    delete reading_review_comment_url(@reading, comment), as: :json

    assert_response :no_content
  end
end
