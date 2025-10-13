namespace :jwt do
  desc 'Clean up expired JWT blacklist tokens'
  task cleanup: :environment do
    puts 'Cleaning up expired JWT blacklist tokens...'

    JwtBlacklistToken.count
    cleaned_count = JwtBlacklistService.cleanup_expired_tokens

    puts "Cleaned up #{cleaned_count} expired tokens"
    puts "Remaining tokens: #{JwtBlacklistToken.count}"

    if cleaned_count.positive?
      puts '✅ Cleanup completed successfully'
    else
      puts 'ℹ️  No expired tokens found'
    end
  end

  desc 'Show JWT blacklist statistics'
  task stats: :environment do
    puts 'JWT Blacklist Statistics:'
    puts '=' * 40

    stats = JwtBlacklistService.blacklist_stats

    puts "Total tokens: #{stats[:total]}"
    puts "Active tokens: #{stats[:active]}"
    puts "Expired tokens: #{stats[:expired]}"
    puts ''
    puts 'By token type:'
    stats[:by_type].each do |type, count|
      puts "  #{type}: #{count}"
    end
    puts ''
    puts 'By user:'
    stats[:by_user].each do |user_id, count|
      puts "  User #{user_id}: #{count}"
    end
  end

  desc 'Clear all JWT blacklist tokens (use with caution)'
  task clear_all: :environment do
    puts '⚠️  WARNING: This will clear ALL JWT blacklist tokens!'
    print "Are you sure? Type 'yes' to continue: "

    confirmation = $stdin.gets.chomp
    if confirmation == 'yes'
      count = JwtBlacklistService.clear_all_blacklisted_tokens
      puts "✅ Cleared #{count} tokens"
    else
      puts '❌ Operation cancelled'
    end
  end

  desc 'Test JWT blacklist functionality'
  task test: :environment do
    puts 'Testing JWT blacklist functionality...'

    # Create a test user
    user = User.find_or_create_by(email: 'test@example.com') do |u|
      u.name = 'Test User'
      u.password = 'password123'
      u.role = 'customer'
    end

    # Generate a token
    token = JwtEncodeService.encode(user)
    puts "Generated token: #{token.first(50)}..."

    # Test blacklisting
    puts 'Blacklisting token...'
    JwtBlacklistService.blacklist_token(token, user_id: user.id.to_s, reason: 'Test')

    # Test if blacklisted
    is_blacklisted = JwtBlacklistService.blacklisted?(token)
    puts "Token is blacklisted: #{is_blacklisted}"

    # Test whitelisting
    puts 'Whitelisting token...'
    JwtBlacklistService.whitelist_token(token)

    # Test if still blacklisted
    is_blacklisted = JwtBlacklistService.blacklisted?(token)
    puts "Token is blacklisted after whitelist: #{is_blacklisted}"

    # Cleanup
    user.destroy
    puts '✅ Test completed successfully'
  end
end
