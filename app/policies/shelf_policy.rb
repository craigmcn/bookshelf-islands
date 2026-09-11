class ShelfPolicy < ApplicationPolicy
  def index? = user.present?
  def show? = record.user == user
  def create? = user.present?
  def update? = record.user == user
  def destroy? = record.user == user

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.where(user: user)
    end
  end
end
