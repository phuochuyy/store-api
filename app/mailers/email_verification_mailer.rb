class EmailVerificationMailer < ApplicationMailer
  default from: 'noreply@store-api.com'

  def verification_email(user)
    @user = user
    @verification_url = verification_url(@user.email_verification_token)

    mail(
      to: @user.email,
      subject: I18n.t('mailers.email_verification.subject'),
      layout: false
    )
  end

  def resend_verification_email(user)
    @user = user
    @verification_url = verification_url(@user.email_verification_token)

    mail(
      to: @user.email,
      subject: I18n.t('mailers.email_verification.resend_subject'),
      layout: false
    )
  end

  private

  def verification_url(token)
    # Use action_mailer default_url_options which is properly configured
    url_options = Rails.application.config.action_mailer.default_url_options || {}
    host = url_options[:host] || 'localhost'
    port = url_options[:port]
    protocol = url_options[:protocol] || 'http'

    base_url = if port
                 "#{protocol}://#{host}:#{port}"
               else
                 "#{protocol}://#{host}"
               end

    "#{base_url}/api/v1/auth/verify_email?token=#{token}"
  end
end
