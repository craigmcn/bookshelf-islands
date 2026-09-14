class TagsController < ApplicationController
  def index
    query = params[:q].to_s.strip
    category = Tag.categories.key?(params[:category]) ? params[:category] : "genre"

    @tags = query.present? ? Tag.where(category: category).where("name ILIKE ?", "%#{query}%").order(:name).limit(10) : []

    render json: @tags.map(&:name)
  end
end
