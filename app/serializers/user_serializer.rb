class UserSerializer
  def initialize(user)
    @user = user
  end

  def as_json
    {
      id: @user.id,
      name: @user.name,
      email: @user.email,
      role: @user.role,
      created_at: @user.created_at&.iso8601,
      updated_at: @user.updated_at&.iso8601
    }
  end
end
