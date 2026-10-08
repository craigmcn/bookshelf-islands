require "test_helper"

class BuddyReadsControllerTest < ActionDispatch::IntegrationTest
  test "guest is redirected to sign in" do
    get buddy_reads_url
    assert_redirected_to sign_in_path
  end

  test "member can invite another member" do
    sign_in_as users(:member)

    assert_difference "BuddyRead.count" do
      post buddy_reads_url, params: {buddy_read: {book_id: books(:one).id, partner_id: users(:moderator).id}}
    end

    buddy_read = BuddyRead.last
    assert_redirected_to buddy_read_url(buddy_read)
    assert buddy_read.pending?
  end

  test "member cannot invite themselves" do
    sign_in_as users(:member)

    assert_no_difference "BuddyRead.count" do
      post buddy_reads_url, params: {buddy_read: {book_id: books(:one).id, partner_id: users(:member).id}}
    end

    assert_response :unprocessable_content
  end

  test "index only shows the current user's buddy reads" do
    mine = BuddyRead.create!(book: books(:one), initiator: users(:member), partner: users(:moderator))
    BuddyRead.create!(book: books(:two), initiator: users(:moderator), partner: users(:admin))

    sign_in_as users(:member)
    get buddy_reads_url

    assert_response :success
    assert_match mine.book.title, response.body
  end

  test "a third party cannot view someone else's buddy read" do
    buddy_read = BuddyRead.create!(book: books(:one), initiator: users(:member), partner: users(:moderator))
    sign_in_as users(:admin)

    get buddy_read_url(buddy_read)

    assert_redirected_to root_url
  end

  test "the invited partner can accept" do
    buddy_read = BuddyRead.create!(book: books(:one), initiator: users(:member), partner: users(:moderator))
    sign_in_as users(:moderator)

    patch buddy_read_url(buddy_read), params: {status: "accepted"}

    assert_redirected_to buddy_read_url(buddy_read)
    assert buddy_read.reload.accepted?
  end

  test "the initiator cannot accept their own invite" do
    buddy_read = BuddyRead.create!(book: books(:one), initiator: users(:member), partner: users(:moderator))
    sign_in_as users(:member)

    patch buddy_read_url(buddy_read), params: {status: "accepted"}

    assert buddy_read.reload.pending?
  end

  test "either participant can cancel a pending invite" do
    buddy_read = BuddyRead.create!(book: books(:one), initiator: users(:member), partner: users(:moderator))
    sign_in_as users(:member)

    patch buddy_read_url(buddy_read), params: {status: "cancelled"}

    assert buddy_read.reload.cancelled?
  end

  test "an accepted buddy read can be marked completed" do
    buddy_read = BuddyRead.create!(book: books(:one), initiator: users(:member), partner: users(:moderator), status: :accepted)
    sign_in_as users(:member)

    patch buddy_read_url(buddy_read), params: {status: "completed"}

    assert buddy_read.reload.completed?
  end

  test "a declined buddy read cannot be marked completed" do
    buddy_read = BuddyRead.create!(book: books(:one), initiator: users(:member), partner: users(:moderator), status: :declined)
    sign_in_as users(:member)

    patch buddy_read_url(buddy_read), params: {status: "completed"}

    assert buddy_read.reload.declined?
  end
end
