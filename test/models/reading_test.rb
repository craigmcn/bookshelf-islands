require "test_helper"

class ReadingTest < ActiveSupport::TestCase
  test "valid with user, book, and status" do
    assert Reading.new(user: users(:member), book: books(:two), status: :want_to_read).valid?
  end

  test "invalid without status" do
    assert_not Reading.new(user: users(:member), book: books(:one)).valid?
  end

  test "valid with a dnf status" do
    assert Reading.new(user: users(:member), book: books(:two), status: :dnf).valid?
  end

  test "status_label renders DNF in all caps" do
    reading = Reading.new(status: :dnf)
    assert_equal "DNF", reading.status_label
  end

  test "status_label humanizes other statuses normally" do
    reading = Reading.new(status: :want_to_read)
    assert_equal "Want to read", reading.status_label
  end

  test "invalid with progress_percent above 100" do
    reading = Reading.new(user: users(:member), book: books(:two), status: :reading, progress_percent: 101)
    assert_not reading.valid?
  end

  test "invalid with progress_percent below 0" do
    reading = Reading.new(user: users(:member), book: books(:two), status: :reading, progress_percent: -1)
    assert_not reading.valid?
  end

  test "valid with a nil progress_percent" do
    assert Reading.new(user: users(:member), book: books(:two), status: :want_to_read, progress_percent: nil).valid?
  end

  test "invalid when finished_on is before started_on" do
    reading = Reading.new(user: users(:member), book: books(:two), status: :finished,
      started_on: Date.new(2026, 1, 10), finished_on: Date.new(2026, 1, 5))
    assert_not reading.valid?
    assert_includes reading.errors[:finished_on], "can't be before the start date"
  end

  test "valid when finished_on is on or after started_on" do
    reading = Reading.new(user: users(:member), book: books(:two), status: :finished,
      started_on: Date.new(2026, 1, 5), finished_on: Date.new(2026, 1, 10))
    assert reading.valid?
  end

  test "defaults to a public review" do
    reading = Reading.create!(user: users(:member), book: books(:two), status: :want_to_read)
    assert reading.is_review_public?
  end

  test "can be created with a format" do
    reading = Reading.create!(user: users(:member), book: books(:two), status: :reading, format: :audiobook)
    assert_equal "audiobook", reading.format
  end

  test "supports multiple reading records for the same user and book (re-reads)" do
    Reading.create!(user: users(:member), book: books(:two), status: :finished)

    assert_difference "Reading.count" do
      Reading.create!(user: users(:member), book: books(:two), status: :want_to_read)
    end
  end
end
