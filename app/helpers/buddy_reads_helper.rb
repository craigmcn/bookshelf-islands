module BuddyReadsHelper
  def buddy_read_status_badge_class(status)
    case status
    when "pending" then "text-bg-warning"
    when "accepted" then "text-bg-success"
    when "declined", "cancelled" then "text-bg-secondary"
    when "completed" then "text-bg-primary"
    end
  end
end
