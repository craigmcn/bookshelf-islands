# ported from community_bookshelf app/controllers/admin/audit_logs_controller.rb
class Admin::AuditLogsController < Admin::BaseController
  before_action :require_admin

  def index
    @pagy, @audit_logs = pagy(AuditLog.recent.includes(:actor))
  end
end
