# ported from community_bookshelf app/controllers/review_comments_controller.rb,
# with format.json added for the ReviewComments island (the browser session
# can't use the token-scoped Api::V1 endpoints).
class ReviewCommentsController < ApplicationController
  before_action :set_reading

  def create
    @review_comment = @reading.review_comments.new(review_comment_params.merge(user: current_user))
    authorize @review_comment

    respond_to do |format|
      if @review_comment.save
        format.html { redirect_to @reading, notice: "Comment posted." }
        format.json { render json: comment_json(@review_comment), status: :created }
      else
        format.html { redirect_to @reading, alert: @review_comment.errors.full_messages.to_sentence }
        format.json { render json: {errors: @review_comment.errors.full_messages}, status: :unprocessable_content }
      end
    end
  end

  def destroy
    @review_comment = @reading.review_comments.find(params[:id])
    authorize @review_comment
    @review_comment.destroy

    respond_to do |format|
      format.html { redirect_to @reading, notice: "Comment removed.", status: :see_other }
      format.json { head :no_content }
    end
  end

  private

  def set_reading
    @reading = Reading.find(params[:reading_id])
  end

  def review_comment_params
    params.expect(review_comment: [:body])
  end

  def comment_json(comment)
    {
      id: comment.id,
      body: comment.body,
      created_at: comment.created_at.iso8601,
      author_name: comment.user.display_name,
      author_path: user_path(comment.user),
      can_destroy: policy(comment).destroy?,
      delete_path: reading_review_comment_path(@reading, comment)
    }
  end
end
