# ported from community_bookshelf app/controllers/shelf_books_controller.rb, with the
# find_by -> find_by! hardening from community_bookshelf issue #176 applied from the start
# (a rescued RecordNotUnique re-lookup that used find_by could still return nil and crash
# on a nil deref if a third concurrent request deleted the row first; find_by! instead
# raises RecordNotFound, which the app already turns into a clean 404).
class ShelfBooksController < ApplicationController
  before_action :set_shelf

  # Adding/removing a book to/from a shelf is a management action on the
  # shelf itself, so it's authorized against the shelf (owner-only) rather
  # than a separate ShelfBookPolicy.
  def create
    authorize @shelf, :update?
    @book = Book.find(params.expect(:book_id))

    begin
      @shelf_book = @shelf.shelf_books.find_or_create_by(book: @book)
    rescue ActiveRecord::RecordNotUnique
      @shelf_book = @shelf.shelf_books.find_by!(book: @book)
    end

    respond_to do |format|
      format.html { redirect_back_or_to @shelf, notice: "Added \"#{@book.title}\" to #{@shelf.name}." }
      format.json { render json: shelf_book_json, status: :created }
    end
  end

  def destroy
    authorize @shelf, :update?
    shelf_book = @shelf.shelf_books.find(params.expect(:id))
    shelf_book.destroy

    respond_to do |format|
      format.html { redirect_back_or_to @shelf, notice: "Removed \"#{shelf_book.book.title}\" from #{@shelf.name}.", status: :see_other }
      format.json { head :no_content }
    end
  end

  private

  def set_shelf
    @shelf = current_user.shelves.find(params.expect(:shelf_id))
  end

  def shelf_book_json
    {id: @shelf_book.id, shelf_id: @shelf.id, book_id: @book.id}
  end
end
