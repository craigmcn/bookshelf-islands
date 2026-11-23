class ApplicationController < ActionController::Base
  include Clearance::Controller
  include Pundit::Authorization
  include Pagy::Method
  include SearchQuery

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  before_action :require_login

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  private

  # an island's fetch would follow a redirect to a 200 HTML page and mistake it for success (#158).
  # html is listed first so a bare */* Accept (curl, a header-less fetch) keeps the redirect.
  def user_not_authorized
    message = "You are not authorized to perform this action."
    redirect = -> {
      flash[:alert] = message
      redirect_back_or_to(root_path)
    }
    respond_to do |format|
      format.html(&redirect)
      format.json { render json: {error: message}, status: :forbidden }
      format.any(&redirect)
    end
  end
end
