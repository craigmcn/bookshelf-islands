# ported from community_bookshelf app/policies/review_like_policy.rb
# Re-checks is_review_public?/review.present? independently rather than
# relying on ReadingPolicy#show? — a moderator can view a private review's
# page but must not be able to like it as if it were public.
class ReviewLikePolicy < ApplicationPolicy
  def create? = user.present? && record.reading.is_review_public? && record.reading.review.present?
  def destroy? = record.user == user
end
