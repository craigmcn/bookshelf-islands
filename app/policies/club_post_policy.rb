# ported from community_bookshelf app/policies/club_post_policy.rb
# No update? — posts are create/destroy only, never edited.
class ClubPostPolicy < ApplicationPolicy
  def create? = record.club.member?(user)
  def destroy? = record.user == user || user&.moderator_or_above?
end
