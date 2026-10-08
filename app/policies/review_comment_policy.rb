# ported from community_bookshelf app/policies/review_comment_policy.rb
# Same independent public/review re-check as ReviewLikePolicy. Unlike likes,
# a moderator can also delete someone else's comment — comment bodies are
# abuse-prone the way a bare like isn't.
class ReviewCommentPolicy < ApplicationPolicy
  def create? = user.present? && record.reading.is_review_public? && record.reading.review.present?
  def destroy? = record.user == user || user&.moderator_or_above?
end
