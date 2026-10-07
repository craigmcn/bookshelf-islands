require "test_helper"

class ReviewLikeTest < ActiveSupport::TestCase
  test "valid with a user and reading" do
    reading = Reading.create!(user: users(:member), book: books(:two), status: :finished, review: "Great.")
    assert ReviewLike.new(user: users(:moderator), reading: reading).valid?
  end

  test "invalid with a duplicate user/reading pair" do
    reading = Reading.create!(user: users(:member), book: books(:two), status: :finished, review: "Great.")
    ReviewLike.create!(user: users(:moderator), reading: reading)

    duplicate = ReviewLike.new(user: users(:moderator), reading: reading)
    assert_not duplicate.valid?
  end
end
