# Preview all emails at http://localhost:3000/rails/mailers/email_verification_mailer
class EmailVerificationMailerPreview < ActionMailer::Preview
  # Preview this email at http://localhost:3000/rails/mailers/email_verification_mailer/verification_email
  def verification_email
    EmailVerificationMailer.verification_email
  end

  # Preview this email at http://localhost:3000/rails/mailers/email_verification_mailer/resend_verification_email
  def resend_verification_email
    EmailVerificationMailer.resend_verification_email
  end
end
