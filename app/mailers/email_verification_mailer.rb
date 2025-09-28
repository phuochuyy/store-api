class EmailVerificationMailer < ApplicationMailer
  default from: 'noreply@store-api.com'

  def verification_email(user)
    @user = user
    @verification_url = verification_url(@user.email_verification_token)

    mail(
      to: @user.email,
      subject: 'Xác thực email của bạn - Store API'
    )
  end

  def resend_verification_email(user)
    @user = user
    @verification_url = verification_url(@user.email_verification_token)

    mail(
      to: @user.email,
      subject: 'Gửi lại email xác thực - Store API'
    )
  end

  private

  def verification_url(token)
    "#{Rails.application.routes.url_helpers.root_url}api/v1/auth/verify_email?token=#{token}"
  end
end
