class BooksController < ApplicationController
  skip_before_action :require_login, only: [:index, :show]
  before_action :set_book, only: %i[show edit update destroy]

  # ported from community_bookshelf app/controllers/books_controller.rb (SORT_OPTIONS + #index)
  SORT_OPTIONS = {
    "title" => {label: "Title", order: {title: :asc}},
    "author" => {label: "Author", order: {author: :asc, title: :asc}},
    "newest" => {label: "Recently Added", order: {created_at: :desc}}
  }.freeze

  def index
    @books = policy_scope(Book).includes(:added_by)
    @genre_tags = Tag.genre.order(:name)

    if params[:q].present?
      query = "%#{params[:q].strip}%"
      @books = @books.where("books.title ILIKE :q OR books.author ILIKE :q", q: query)
    end

    if params[:tag].present?
      @tag = Tag.genre.find_by(name: params[:tag].to_s.strip.downcase)
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
    params.expect(book: [:title, :author, :cover_url, :tag_list])
  end

  def catalog_page_json
    {
      books: @books.map { |book| catalog_book_json(book) },
      sort: @sort,
      tag: @tag&.name,
      genre_tags: @genre_tags.map { |tag| {name: tag.name} },
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
end
