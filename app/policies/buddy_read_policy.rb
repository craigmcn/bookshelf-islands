# ported from community_bookshelf app/policies/buddy_read_policy.rb
# No moderator override anywhere — deliberately a private two-person space,
# unlike reviews/clubs.
class BuddyReadPolicy < ApplicationPolicy
  def index? = user.present?
  def show? = record.participant?(user)
  def create? = user.present?
  def update? = record.participant?(user) # backs accept/decline (partner only) and cancel (either participant)
  def destroy? = record.participant?(user) # unused — controller has no destroy action

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.where(initiator: user).or(scope.where(partner: user))
    end
  end
end
