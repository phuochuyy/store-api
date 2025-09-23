class CategoryPolicy < BasePolicy
  def index?
    authenticated?
  end

  def show?
    authenticated?
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
end
