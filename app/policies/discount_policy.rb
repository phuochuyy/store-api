class DiscountPolicy < BasePolicy
  def index?
    user.present?
  end

  def show?
    user.present?
  end

  def create?
    admin?
  end

  def update?
    admin?
  end

  def destroy?
    admin?
  end

  def stats?
    admin?
  end

  def generate_codes?
    admin?
  end

  def validate?
    user.present?
  end

  private

  def admin?
    user&.admin?
  end
end
