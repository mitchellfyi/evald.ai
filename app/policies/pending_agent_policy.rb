# frozen_string_literal: true

class PendingAgentPolicy < ApplicationPolicy
  def index?
    user&.has_role?(:admin) || user&.admin?
  end

  def show?
    user&.has_role?(:admin) || user&.admin?
  end

  def approve?
    user&.has_role?(:admin) || user&.admin?
  end

  def reject?
    user&.has_role?(:admin) || user&.admin?
  end

  class Scope < Scope
    def resolve
      scope.all
    end
  end
end
