class PromotionPolicy < BasePolicy
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

  def apply?
    user.present?
  end

  def applicable?
    user.present?
  end

  private

  def admin?
    user&.admin?
  end
end
