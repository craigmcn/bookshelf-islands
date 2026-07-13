class BookSearchController < ApplicationController
  def index
    query = params[:q].to_s.strip

    @results = query.present? ? OpenLibraryService.search(query) : []

    render json: @results
  end
end
