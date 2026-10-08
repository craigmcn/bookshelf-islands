class ReadingPolicy < ApplicationPolicy
  # ported from community_bookshelf app/policies/reading_policy.rb — lets any
  # signed-in user view a reading whose review is public, not just its owner
  # or a moderator. Without this, a public review would be unreachable to
  # like/comment on at all, since reading_path only shows it through #show.
  def show? = (!record.deleted? && (record.user == user || (record.is_review_public? && record.review.present?))) || user&.moderator_or_above?
  def edit? = !record.deleted? && (record.user == user || user&.moderator_or_above?)
  def create? = user.present?
  def update? = !record.deleted? && (record.user == user || user&.moderator_or_above?)
  def destroy? = !record.deleted? && user&.moderator_or_above?

  class Scope < ApplicationPolicy::Scope
    def resolve
      if user&.moderator_or_above?
        scope.all
      else
        scope.where(user: user)
      end
    end
  end
end
