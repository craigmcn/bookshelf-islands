class Admin::UsersController < Admin::BaseController
  before_action :require_admin

  # excluding_deleted_placeholder: ported from community_bookshelf app/controllers/admin/users_controller.rb
  def index
    @users = User.excluding_deleted_placeholder.order(:email).includes(:roles)
  end

  def edit
    @user = User.excluding_deleted_placeholder.find(params[:id])
    @roles = Role.all.order(:name)
  end

  def update
    @user = User.excluding_deleted_placeholder.find(params[:id])
    update_roles_with_audit!(@user, Role.where(id: params.dig(:user, :role_ids) || []))
    redirect_to admin_users_path, notice: "Roles updated."
  end
end
