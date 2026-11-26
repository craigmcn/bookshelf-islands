require "test_helper"

class Admin::UsersControllerTest < ActionDispatch::IntegrationTest
  test "guest is redirected to sign in" do
    get admin_users_url
    assert_redirected_to sign_in_path
  end

  test "member gets forbidden" do
    sign_in_as users(:member)
    get admin_users_url
    assert_response :forbidden
  end

  test "admin can list users" do
    sign_in_as users(:admin)
    get admin_users_url
    assert_response :success
  end

  test "admin can update a user role" do
    sign_in_as users(:admin)
    patch admin_user_url(users(:member)), params: {user: {role_ids: [roles(:moderator).id]}}
    assert_redirected_to admin_users_path
    assert users(:member).reload.moderator?
  end

  # ported from community_bookshelf test/controllers/admin/users_controller_test.rb
  test "updating a user's roles writes an audit log entry" do
    admin = users(:admin)
    sign_in_as admin

    assert_difference "AuditLog.count", 1 do
      patch admin_user_url(users(:member)), params: {user: {role_ids: [roles(:moderator).id]}}
    end

    audit_log = AuditLog.last
    assert_equal admin, audit_log.actor
    assert_equal "update_roles", audit_log.action
    assert_equal users(:member), audit_log.subject
    assert_equal ["member"], audit_log.details["from"]
    assert_equal ["moderator"], audit_log.details["to"]
  end

  test "a moderator can't change roles, so nothing is audited" do
    sign_in_as users(:moderator)
    assert_no_difference("AuditLog.count") { patch admin_user_url(users(:member)), params: {user: {role_ids: [roles(:admin).id]}} }
    assert_response :forbidden
    assert_not users(:member).reload.admin?
  end
end
