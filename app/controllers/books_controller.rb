class BooksController < ApplicationController
  skip_before_action :require_login, only: [:index, :show]
  before_action :set_book, only: %i[show edit update destroy]

  # ported from community_bookshelf app/controllers/books_controller.rb (SORT_OPTIONS + #index)
  SORT_OPTIONS = {
    "title" => {label: "Title", order: {title: :asc}},
    "author" => {label: "Author", order: {author: :asc, title: :asc}},
    "newest" => {label: "Recently Added", order: {created_at: :desc}},
    # published_on is a brand-new optional field most books won't have yet; NULLS LAST keeps
    # undated books from crowding out the ones that actually have a date (Postgres' default
    # DESC puts NULLs first), matching SeriesController#show's NULLS LAST ordering.
    "published" => {label: "Publication Date", order: Arel.sql("published_on DESC NULLS LAST")}
  }.freeze

  def index
    @books = policy_scope(Book).includes(:added_by)
    @genre_tags = Tag.genre.order(:name)
    @mood_tags = Tag.mood.order(:name)
    @pace_tags = Tag.pace.order(:name)

    if params[:q].present?
      query = "%#{params[:q].strip}%"
      @books = @books.where("books.title ILIKE :q OR books.author ILIKE :q", q: query)
    end

    if params[:tag].present?
      @tag = Tag.find_by(name: params[:tag].to_s.strip.downcase)
      @books = @tag ? @books.joins(:tags).where(tags: {id: @tag.id}) : @books.none
    end

    @sort = SORT_OPTIONS.key?(params[:sort]) ? params[:sort] : "title"
    @books = @books.order(SORT_OPTIONS[@sort][:order])

    @pagy, @books = pagy(@books, limit: 12)
    @catalog_json = catalog_page_json

    respond_to do |format|
      format.html
      format.json { render json: @catalog_json }
    end
  end

  def show
    authorize @book
    @user_reading = current_user&.readings&.find_by(book: @book)
    @shelf_picker_json = shelf_picker_json
    @similar_books = @book.similar_books
  end

  def new
    @book = Book.new
  end

  def edit
    authorize @book
  end

  def create
    @book = Book.new(book_params.merge(added_by: current_user))
    authorize @book

    # ported from community_bookshelf app/controllers/books_controller.rb (#create open_library_key lookup)
    detail = OpenLibraryService.work_detail(@book.open_library_key)
    @book.description = detail[:description] if detail[:description].present?
    @book.subjects = detail[:subjects] if detail[:subjects].present?

    if @book.save
      redirect_to @book, notice: "Book was successfully created."
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    authorize @book
    if @book.update(book_params)
      redirect_to @book, notice: "Book was successfully updated.", status: :see_other
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    authorize @book
    @book.destroy!
    redirect_to books_path, notice: "Book was successfully destroyed.", status: :see_other
  end

  private

  def set_book
    @book = Book.find(params.expect(:id))
  end

  def book_params
    params.expect(book: [:title, :author, :cover_url, :isbn, :page_count, :published_on, :open_library_key,
      :series_id, :series_position, :tag_list, :mood_list, :pace_list])
  end

  def catalog_page_json
    {
      books: @books.map { |book| catalog_book_json(book) },
      sort: @sort,
      tag: @tag&.name,
      genre_tags: @genre_tags.map { |tag| {name: tag.name} },
      mood_tags: @mood_tags.map { |tag| {name: tag.name} },
      pace_tags: @pace_tags.map { |tag| {name: tag.name} },
      pagy: {page: @pagy.page, pages: @pagy.pages, count: @pagy.count}
    }
  end

  def catalog_book_json(book)
    {
      id: book.id,
      title: book.title,
      author: book.author,
      cover_url: book.cover_url.presence,
      added_by_email: book.added_by.email,
      path: book_path(book)
    }
  end

  def shelf_picker_json
    return [] unless current_user

    shelf_book_ids = ShelfBook.where(shelf: current_user.shelves, book: @book).pluck(:shelf_id, :id).to_h
    current_user.shelves.order(:name).map do |shelf|
      {id: shelf.id, name: shelf.name, shelf_book_id: shelf_book_ids[shelf.id]}
    end
  end
end
