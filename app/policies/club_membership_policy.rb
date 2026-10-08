# ported from community_bookshelf app/policies/club_membership_policy.rb
class ClubMembershipPolicy < ApplicationPolicy
  def create? = user.present? && !record.club.member?(user)
  def destroy? = record.user == user
end
