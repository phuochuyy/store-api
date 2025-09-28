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
    host = Rails.application.config.default_url_options[:host]
    port = Rails.application.config.default_url_options[:port]
    protocol = Rails.application.config.default_url_options[:protocol] || 'http'

    base_url = if port
                 "#{protocol}://#{host}:#{port}"
               else
                 "#{protocol}://#{host}"
               end

    "#{base_url}/api/v1/auth/verify_email?token=#{token}"
  end
end
