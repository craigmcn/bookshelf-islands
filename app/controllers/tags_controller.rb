class TagsController < ApplicationController
  def index
    query = params[:q].to_s.strip

    @tags = query.present? ? Tag.genre.where("name ILIKE ?", "%#{query}%").order(:name).limit(10) : []

    render json: @tags.map(&:name)
  end
end
