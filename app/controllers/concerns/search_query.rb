# ported from community_bookshelf app/controllers/concerns/search_query.rb (community_bookshelf#242)
# ?q= can arrive as an array or hash (q[]=x, q[k]=x); treating that as no search,
# rather than calling String methods on it, keeps a crafted link from raising a 500.
module SearchQuery
  extend ActiveSupport::Concern

  private

  def search_query
    params[:q].strip.presence if params[:q].is_a?(String)
  end
end
