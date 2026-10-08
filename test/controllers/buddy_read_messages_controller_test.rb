require "test_helper"

class BuddyReadMessagesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @buddy_read = BuddyRead.create!(book: books(:one), initiator: users(:member), partner: users(:moderator))
  end

  test "a participant can post a message" do
    sign_in_as users(:member)

    assert_difference "@buddy_read.messages.count" do
      post buddy_read_messages_url(@buddy_read), params: {buddy_read_message: {body: "Chapter 1 was great!"}}
    end

    assert_redirected_to buddy_read_url(@buddy_read)
  end

  test "a third party cannot post a message" do
    sign_in_as users(:admin)

    assert_no_difference "@buddy_read.messages.count" do
      post buddy_read_messages_url(@buddy_read), params: {buddy_read_message: {body: "Butting in!"}}
    end
    assert_redirected_to root_url
  end

  test "a participant cannot post after the buddy read is declined" do
    @buddy_read.update!(status: :declined)
    sign_in_as users(:member)

    assert_no_difference "@buddy_read.messages.count" do
      post buddy_read_messages_url(@buddy_read), params: {buddy_read_message: {body: "Still there?"}}
    end
    assert_redirected_to root_url
  end

  test "a participant cannot post after the buddy read is cancelled" do
    @buddy_read.update!(status: :cancelled)
    sign_in_as users(:member)

    assert_no_difference "@buddy_read.messages.count" do
      post buddy_read_messages_url(@buddy_read), params: {buddy_read_message: {body: "Still there?"}}
    end
    assert_redirected_to root_url
  end
end
