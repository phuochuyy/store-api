class BasePolicy
  attr_reader :user, :record

  def initialize(user, record)
    @user = user
    @record = record
  end

  def index?
    false
  end

  def show?
    false
  end

  def create?
    false
  end

  def update?
    false
  end

  def destroy?
    false
  end

  private

  def admin?
    user&.admin?
  end

  def owner?
    user == record.user
  end

  def authenticated?
    user.present?
  end
end
