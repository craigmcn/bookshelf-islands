require "test_helper"

class ReviewCommentTest < ActiveSupport::TestCase
  test "valid with a user, reading, and body" do
    reading = Reading.create!(user: users(:member), book: books(:two), status: :finished, review: "Great.")
    assert ReviewComment.new(user: users(:moderator), reading: reading, body: "Nice!").valid?
  end

  test "invalid without a body" do
    reading = Reading.create!(user: users(:member), book: books(:two), status: :finished, review: "Great.")
    assert_not ReviewComment.new(user: users(:moderator), reading: reading).valid?
  end

  test "invalid with a body over 1000 characters" do
    reading = Reading.create!(user: users(:member), book: books(:two), status: :finished, review: "Great.")
    assert_not ReviewComment.new(user: users(:moderator), reading: reading, body: "a" * 1001).valid?
  end

  test "commenting on someone else's review creates a notification for the owner" do
    reading = Reading.create!(user: users(:member), book: books(:two), status: :finished, review: "Great.")

    assert_difference "Notification.count", 1 do
      ReviewComment.create!(user: users(:moderator), reading: reading, body: "Nice!")
    end

    notification = Notification.last
    assert_equal users(:member), notification.recipient
    assert_equal users(:moderator), notification.actor
    assert notification.review_comment?
  end

  test "commenting on your own review does not create a notification" do
    reading = Reading.create!(user: users(:member), book: books(:two), status: :finished, review: "Great.")

    assert_no_difference "Notification.count" do
      ReviewComment.create!(user: users(:member), reading: reading, body: "Thanks me!")
    end
  end

  test "destroying the comment destroys its notification" do
    reading = Reading.create!(user: users(:member), book: books(:two), status: :finished, review: "Great.")
    comment = ReviewComment.create!(user: users(:moderator), reading: reading, body: "Nice!")

    assert_difference "Notification.count", -1 do
      comment.destroy
    end
  end
end
