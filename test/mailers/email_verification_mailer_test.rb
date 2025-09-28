require "test_helper"

class EmailVerificationMailerTest < ActionMailer::TestCase
  test "verification_email" do
    mail = EmailVerificationMailer.verification_email
    assert_equal "Verification email", mail.subject
    assert_equal [ "to@example.org" ], mail.to
    assert_equal [ "from@example.com" ], mail.from
    assert_match "Hi", mail.body.encoded
  end

  test "resend_verification_email" do
    mail = EmailVerificationMailer.resend_verification_email
    assert_equal "Resend verification email", mail.subject
    assert_equal [ "to@example.org" ], mail.to
    assert_equal [ "from@example.com" ], mail.from
    assert_match "Hi", mail.body.encoded
  end
end
