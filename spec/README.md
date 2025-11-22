# Testing Guide

## Overview

This project uses RSpec for testing with the following gems:
- **RSpec Rails**: Testing framework
- **FactoryBot**: Test data generation
- **Shoulda Matchers**: Simplified model testing
- **Database Cleaner**: Database state management

## Running Tests

### Using the test script (recommended)

```bash
# Run all tests
./bin/test --all

# Run user model tests only
./bin/test --user

# Run with verbose output
./bin/test --user --verbose

# Run specific test files
./bin/test spec/models/user_working_spec.rb
```

### Using RSpec directly

```bash
# Run all tests
bundle exec rspec

# Run specific test file
bundle exec rspec spec/models/user_working_spec.rb

# Run with documentation format
bundle exec rspec --format documentation

# Run specific test
bundle exec rspec spec/models/user_working_spec.rb:25
```

## Test Structure

### User Model Tests (`spec/models/user_working_spec.rb`)

The User model tests cover:

- **Basic functionality**: Creation, validations, email format
- **Associations**: Relationships with carts and notifications
- **Enums**: Role management (admin/customer)
- **Scopes**: Filtering and ordering methods
- **Authentication**: Login/logout functionality
- **Email verification**: Token generation and verification
- **Display methods**: Name display logic
- **Database constraints**: Unique email enforcement
- **Class methods**: User finding methods
- **Security**: Password hashing

### Factory (`spec/factories/users.rb`)

The User factory provides:

- **Basic user**: Standard user with required fields
- **Traits**:
  - `:admin` - Admin user
  - `:customer` - Customer user
  - `:with_profile` - User with complete profile
  - `:verified` - Email verified user
  - `:unverified` - Email not verified user
  - `:with_preferences` - User with notification preferences

## Test Results

Current test status: **31 examples, 0 failures**

All User model functionality is thoroughly tested and working correctly.

## Configuration

### Database Cleaner

Tests use Database Cleaner to ensure clean state between tests:
- Strategy: Transaction-based
- Automatic cleanup after each test

### RSpec Configuration

- Located in `spec/rails_helper.rb`
- Includes FactoryBot and Shoulda Matchers
- Configured for Rails environment

## Troubleshooting

### Ruby LSP Issues

If you encounter Ruby LSP test running issues:

1. The project includes `.ruby-lsp.yml` to disable test running through LSP
2. Use the `./bin/test` script or `bundle exec rspec` directly
3. VS Code settings are configured in `.vscode/settings.json`

### Database Issues

If tests fail due to database state:

```bash
# Reset test database
bundle exec rails db:test:prepare

# Run migrations for test environment
bundle exec rails db:migrate RAILS_ENV=test
```

## Adding New Tests

1. Create test files in appropriate `spec/` subdirectories
2. Use FactoryBot for test data generation
3. Follow RSpec conventions and naming
4. Include both positive and negative test cases
5. Test edge cases and error conditions

## Best Practices

- Use descriptive test names
- Keep tests focused and atomic
- Use factories instead of fixtures
- Test both success and failure scenarios
- Maintain test independence
- Use appropriate matchers and assertions
