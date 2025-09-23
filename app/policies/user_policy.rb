class UserPolicy < BasePolicy
  def index?
    admin?
  end

  def show?
    admin? || owner?
  end

  def create?
    admin?
  end

  def update?
    admin? || owner?
  end

  def destroy?
    admin?
  end

  private

  def owner?
    user == record
  end
end
