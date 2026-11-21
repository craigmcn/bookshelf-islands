class ReadingsController < ApplicationController
  before_action :set_reading, only: %i[show edit update destroy]

  # ported from community_bookshelf app/controllers/readings_controller.rb (SORT_OPTIONS + #index, community_bookshelf#218)
  # Each order ends with an id tiebreaker in its own direction, so tied rows can't shift between Pagy's pages.
  SORT_OPTIONS = {
    "recent" => {label: "Recently Updated", order: {updated_at: :desc, id: :desc}},
    "title" => {label: "Book Title", order: {"books.title": :asc, id: :asc}},
    # rating is nullable ("No rating"); Postgres' DESC puts NULLs first, burying the rated readings.
    "rating" => {label: "Rating (high to low)", order: Arel.sql("readings.rating DESC NULLS LAST, readings.id DESC")}
  }.freeze

  def index
    @readings = current_user.readings.includes(:book).joins(:book)
    # Only filters that actually narrowed the query; a non-string q and unknown status/rating are ignored.
    @filters_applied = false

    @query = search_query
    if @query
      query = "%#{@query}%"
      @readings = @readings.where("books.title ILIKE :q OR books.author ILIKE :q", q: query)
      @filters_applied = true
    end

    if params[:status].present? && Reading.statuses.key?(params[:status])
      @readings = @readings.where(status: params[:status])
      @filters_applied = true
    end

    if params[:rating].present? && Reading.ratings.key?(params[:rating])
      @readings = @readings.where(rating: params[:rating])
      @filters_applied = true
    end

    if params[:tag].present?
      @tag = Tag.genre.find_by(name: params[:tag].to_s.strip.downcase)
      @readings = @tag ? @readings.merge(Book.joins(:tags).where(tags: {id: @tag.id})) : @readings.none
      @filters_applied = true
    end

    @sort = SORT_OPTIONS.key?(params[:sort]) ? params[:sort] : "recent"
    @readings = @readings.order(SORT_OPTIONS[@sort][:order])

    @shelf_tags = Tag.genre.joins(books: :readings).where(readings: {user: current_user}).distinct.order(:name)

    @pagy, @readings = pagy(@readings, limit: 10)
    @recommended_books = Book.recommended_for(current_user)
    @shelf_json = shelf_page_json

    respond_to do |format|
      format.html
      format.json { render json: @shelf_json }
    end
  end

  def show
    authorize @reading
    @review_comments = @reading.review_comments.includes(:user)
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
    params.expect(reading: [:book_id, :status, :rating, :review, :started_on, :finished_on, :progress_percent, :format, :is_review_public])
  end

  def shelf_page_json
    {
      readings: @readings.map { |reading| shelf_reading_json(reading) },
      sort: @sort,
      tag: @tag&.name,
      shelf_tags: @shelf_tags.map { |tag| {name: tag.name} },
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
      status_label: reading.status_label,
      rating: reading.rating,
      rating_stars: reading.rating? ? Reading.ratings[reading.rating] : nil,
      progress_percent: reading.progress_percent,
      review: reading.review,
      path: reading_path(reading),
      edit_path: edit_reading_path(reading),
      can_edit: policy(reading).edit?,
      can_destroy: policy(reading).destroy?
    }
  end
end
