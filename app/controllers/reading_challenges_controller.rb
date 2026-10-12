# ported from community_bookshelf app/controllers/reading_challenges_controller.rb
class ReadingChallengesController < ApplicationController
  before_action :set_reading_challenge, only: %i[edit update]

  def index
    authorize ReadingChallenge
    @reading_challenges = current_user.reading_challenges.order(year: :desc)
  end

  def new
    @reading_challenge = current_user.reading_challenges.build(year: Date.current.year)
  end

  def edit
    authorize @reading_challenge
  end

  def create
    @reading_challenge = current_user.reading_challenges.build(reading_challenge_params_for_create)
    authorize @reading_challenge
    if @reading_challenge.save
      redirect_to reading_challenges_path, notice: "Reading challenge was successfully created."
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    authorize @reading_challenge
    if @reading_challenge.update(reading_challenge_params_for_update)
      redirect_to reading_challenges_path, notice: "Reading challenge was successfully updated.", status: :see_other
    else
      render :edit, status: :unprocessable_content
    end
  end

  private

  # Scoped to current_user.reading_challenges (not a bare ReadingChallenge.find)
  # so a non-owner id 404s before authorize is even reached.
  def set_reading_challenge
    @reading_challenge = current_user.reading_challenges.find(params[:id])
  end

  # year is only accepted on create, never update — otherwise a crafted
  # update request could change which year a challenge counts toward.
  def reading_challenge_params_for_create
    params.expect(reading_challenge: [:year, :goal])
  end

  def reading_challenge_params_for_update
    params.expect(reading_challenge: [:goal])
  end
end
