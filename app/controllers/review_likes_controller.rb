# ported from community_bookshelf app/controllers/review_likes_controller.rb,
# with format.json added for the ReviewLikeButton island (the browser session
# can't use the token-scoped Api::V1 endpoints).
class ReviewLikesController < ApplicationController
  before_action :set_reading

  def create
    @review_like = ReviewLike.new(user: current_user, reading: @reading)
    authorize @review_like
    @review_like.save

    respond_to do |format|
      format.html { redirect_to @reading }
      format.json { render json: like_state }
    end
  end

  def destroy
    @review_like = current_user.review_likes.find_by(reading_id: @reading.id)
    if @review_like
      authorize @review_like
      @review_like.destroy
    end

    respond_to do |format|
      format.html { redirect_to @reading, status: :see_other }
      format.json { render json: like_state }
    end
  end

  private

  def set_reading
    @reading = Reading.find(params[:reading_id])
  end

  def like_state
    {liked: @reading.review_likes.exists?(user_id: current_user.id), count: @reading.review_likes.count}
  end
end
