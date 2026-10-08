# ported from community_bookshelf app/models/club_membership.rb
class ClubMembership < ApplicationRecord
  belongs_to :club
  belongs_to :user

  validates :user_id, uniqueness: {scope: :club_id}
end
