class PhonePolicy < BasePolicy
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

  def upload_image?
    admin?
  end

  def remove_image?
    admin?
  end
end
