# ported from community_bookshelf app/policies/reading_challenge_policy.rb
class ReadingChallengePolicy < ApplicationPolicy
  def index? = user.present?
  def create? = user.present? && record.user == user
  def update? = record.user == user

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.where(user: user)
    end
  end
end
