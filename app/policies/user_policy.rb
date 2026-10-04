# ported from community_bookshelf app/policies/user_policy.rb (edit?/update?/destroy? only — show? backs a public
# profile page that isn't implemented here, see Social roadmap category)
class UserPolicy < ApplicationPolicy
  # Backs AccountsController, which only ever loads current_user (never a
  # params[:id]) — these checks exist to pin that invariant with the same
  # authorization layer every other model in this app uses, not because the
  # controller branches on ownership today.
  def edit? = record == user
  def update? = record == user
  def destroy? = record == user
end
