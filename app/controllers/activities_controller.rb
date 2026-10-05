# ported from community_bookshelf app/controllers/activities_controller.rb
class ActivitiesController < ApplicationController
  def index
    @activities = Activity.where(user: current_user.following)
      .includes(:user, reading: :book)
      .order(created_at: :desc)
    @pagy, @activities = pagy(@activities)
  end
end
