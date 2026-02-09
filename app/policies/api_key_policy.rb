class ApiKeyPolicy < ApplicationPolicy
  def index?
    true  # Users can see their own keys
  end

  def show?
    record.user == user
  end

  def create?
    true  # Any user can create API keys
  end

  def destroy?
    record.user == user || user&.has_role?(:admin)
  end

  class Scope < Scope
    def resolve
      if user&.has_role?(:admin)
        scope.all
      else
        scope.where(user: user)
      end
    end
  end
end
