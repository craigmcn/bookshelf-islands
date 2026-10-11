# ported from community_bookshelf app/controllers/notifications_controller.rb
# No policy class: inherently scoped to current_user, the same pattern
# ActivitiesController (/feed) uses.
class NotificationsController < ApplicationController
  include NotificationsHelper

  def index
    @notifications = current_user.notifications.includes(:actor, :notifiable).recent
    @pagy, @notifications = pagy(@notifications)
    @notifications = Notification.preload_notifiable_details(@notifications)
  end

  # Marks a single notification read as its link is followed, then redirects
  # to the underlying resource (the follower's profile, the reading, the
  # club, or the buddy read) rather than back to the notifications list.
  def update
    notification = current_user.notifications.find(params[:id])
    notification.mark_read!
    redirect_to notification_path_for(notification)
  end

  def mark_all_read
    current_user.notifications.unread.update_all(read_at: Time.current)
    redirect_back_or_to notifications_path
  end
end
