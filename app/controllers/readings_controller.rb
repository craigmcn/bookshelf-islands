class ReadingsController < ApplicationController
  before_action :set_reading, only: %i[show edit update destroy]

  # ported from community_bookshelf app/controllers/readings_controller.rb (SORT_OPTIONS + #index),
  # minus the tag filter (needs the Tag/Tagging model from #23, not yet ported)
  SORT_OPTIONS = {
    "recent" => {label: "Recently Updated", order: {updated_at: :desc}},
    "title" => {label: "Book Title", order: {"books.title": :asc}},
    "rating" => {label: "Rating (High to Low)", order: {rating: :desc}}
  }.freeze

  def index
    @readings = current_user.readings.includes(:book).joins(:book)

    if params[:q].present?
      query = "%#{params[:q].strip}%"
      @readings = @readings.where("books.title ILIKE :q OR books.author ILIKE :q", q: query)
    end

    if params[:status].present? && Reading.statuses.key?(params[:status])
      @readings = @readings.where(status: params[:status])
    end

    if params[:rating].present? && Reading.ratings.key?(params[:rating])
      @readings = @readings.where(rating: params[:rating])
    end

    @sort = SORT_OPTIONS.key?(params[:sort]) ? params[:sort] : "recent"
    @readings = @readings.order(SORT_OPTIONS[@sort][:order])

    @pagy, @readings = pagy(@readings, limit: 10)
    @shelf_json = shelf_page_json

    respond_to do |format|
      format.html
      format.json { render json: @shelf_json }
    end
  end

  def show
    authorize @reading
  end

  def new
    @reading = Reading.new(book_id: params[:book_id])
  end

  def edit
    authorize @reading
  end

  def create
    @reading = Reading.new(reading_params.merge(user_id: current_user.id))
    authorize @reading

    respond_to do |format|
      if @reading.save
        format.html { redirect_to @reading, notice: "Reading was successfully created." }
        format.json { render json: shelf_reading_json(@reading), status: :created }
      else
        format.html { render :new, status: :unprocessable_content }
        format.json { render json: {errors: @reading.errors.full_messages}, status: :unprocessable_content }
      end
    end
  end

  def update
    authorize @reading
    if @reading.update(reading_params)
      redirect_to @reading, notice: "Reading was successfully updated.", status: :see_other
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    authorize @reading
    @reading.soft_delete
    respond_to do |format|
      format.html { redirect_to readings_path, notice: "Reading was removed.", status: :see_other }
      format.json { head :no_content }
    end
  end

  private

  def set_reading
    @reading = Reading.with_deleted.find(params.expect(:id))
  end

  def reading_params
    params.expect(reading: [:book_id, :status, :rating, :review])
  end

  def shelf_page_json
    {
      readings: @readings.map { |reading| shelf_reading_json(reading) },
      sort: @sort,
      pagy: {page: @pagy.page, pages: @pagy.pages, count: @pagy.count}
    }
  end

  def shelf_reading_json(reading)
    {
      id: reading.id,
      book_id: reading.book_id,
      book_title: reading.book.title,
      book_author: reading.book.author,
      book_path: book_path(reading.book),
      status: reading.status,
      status_label: reading.status.humanize,
      rating: reading.rating,
      rating_stars: reading.rating? ? Reading.ratings[reading.rating] : nil,
      review: reading.review,
      path: reading_path(reading),
      edit_path: edit_reading_path(reading),
      can_edit: policy(reading).edit?,
      can_destroy: policy(reading).destroy?
    }
  end
end
