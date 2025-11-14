# Testing Guide

## Running Tests in Docker

### Prerequisites

1. **Start Docker Compose services:**
   ```bash
   docker compose up -d
   ```

2. **Setup test database:**
   ```bash
   make db-test-setup
   # or
   docker compose exec -e RAILS_ENV=test web bundle exec rails db:create db:schema:load
   ```

### Running Tests

#### All Tests
```bash
make test
# or
docker compose exec web bundle exec rspec
```

#### Authentication Tests Only
```bash
make test-auth
# or
docker compose exec web bundle exec rspec spec/services/auth spec/controllers/api/v1/auth_controller_spec.rb
```

#### Specific Test File
```bash
make test-single FILE=spec/services/auth/auth_service_spec.rb
# or
docker compose exec web bundle exec rspec spec/services/auth/auth_service_spec.rb
```

#### With Coverage
```bash
make test-coverage
```

#### Watch Mode (for development)
```bash
make test-watch
```

### Test Environment Configuration

#### Redis Configuration
- **Docker**: Uses `redis://redis:6379/1` (from REDIS_URL env var)
- **Local**: Uses `redis://localhost:6379/1` (fallback)
- Tests will automatically skip if Redis is not available

#### Database Configuration
- Test database: `store_api_test`
- Automatically cleaned between tests using DatabaseCleaner
- Uses transaction strategy for speed

### Test Structure

```
spec/
├── controllers/
│   └── api/v1/
│       └── auth_controller_spec.rb
├── models/
│   └── jwt_blacklist_token_spec.rb
├── services/
│   └── auth/
│       ├── auth_service_spec.rb
│       ├── jwt/
│       │   ├── cache_service_spec.rb
│       │   ├── blacklist_service_spec.rb
│       │   ├── decode_service_spec.rb
│       │   └── encode_service_spec.rb
│       └── token_validation_service_spec.rb
└── support/
    └── redis_helper.rb
```

### Test Coverage

#### Authentication Tests
- ✅ Login/Register with device tracking
- ✅ Token refresh with rotation
- ✅ Device validation
- ✅ IP validation (lenient)
- ✅ Token expiry (30 min access, 7 days refresh)
- ✅ Token blacklisting
- ✅ Redis caching
- ✅ Backward compatibility

#### Cache Service Tests
- ✅ Blacklist caching
- ✅ User caching
- ✅ Validation caching
- ✅ Cache invalidation
- ✅ Token tracking
- ✅ Redis fallback handling

### Troubleshooting

#### Redis Connection Issues
If tests fail with Redis connection errors:
1. Check Redis is running: `docker compose ps redis`
2. Check REDIS_URL: `docker compose exec web env | grep REDIS_URL`
3. Tests will skip if Redis unavailable (graceful degradation)

#### Database Issues
If test database errors occur:
```bash
# Reset test database
docker compose exec -e RAILS_ENV=test web bundle exec rails db:drop db:create db:schema:load
```

#### Test Failures
1. **Clear Redis cache:**
   ```bash
   docker compose exec redis redis-cli FLUSHDB
   ```

2. **Check logs:**
   ```bash
   docker compose logs web
   ```

3. **Run single test for debugging:**
   ```bash
   make test-single FILE=spec/services/auth/auth_service_spec.rb
   ```

### Best Practices

1. **Always run tests before committing:**
   ```bash
   make test
   ```

2. **Run auth tests during development:**
   ```bash
   make test-auth
   ```

3. **Use watch mode for TDD:**
   ```bash
   make test-watch
   ```

4. **Check coverage regularly:**
   ```bash
   make test-coverage
   ```

### CI/CD Integration

Tests are configured to run in CI/CD pipelines:
- GitHub Actions (see `.github/workflows/ci.yml`)
- Automatic test database setup
- Redis service available
- Coverage reporting

