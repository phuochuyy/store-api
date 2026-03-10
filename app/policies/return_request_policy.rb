# frozen_string_literal: true

class ReturnRequestPolicy < BasePolicy
  def show?
    admin? || owner?
  end

  # Approve, reject, complete: admin only
  def update?
    admin?
  end
end
