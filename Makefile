# Store API Makefile
# Common commands for development and deployment

.PHONY: help setup start stop restart logs clean test lint security docs

# Default target
help:
	@echo "Store API - Available Commands:"
	@echo ""
	@echo "Setup & Development:"
	@echo "  setup     - Initial project setup"
	@echo "  start     - Start the application"
	@echo "  stop      - Stop the application"
	@echo "  restart   - Restart the application"
	@echo "  logs      - Show application logs"
	@echo "  clean     - Clean up containers and volumes"
	@echo ""
	@echo "Database:"
	@echo "  db-setup  - Setup database (create, migrate, seed)"
	@echo "  db-reset  - Reset database (drop, create, migrate, seed)"
	@echo "  db-migrate- Run database migrations"
	@echo "  db-seed   - Seed database with sample data"
	@echo "  db-console- Open database console"
	@echo "  db-fix    - Fix missing store_api database"
	@echo ""
	@echo "Code Quality:"
	@echo "  test      - Run tests"
	@echo "  lint      - Run RuboCop"
	@echo "  security  - Run Brakeman security scan"
	@echo "  format    - Format code with RuboCop"
	@echo ""
	@echo "Utilities:"
	@echo "  console   - Open Rails console"
	@echo "  shell     - Open shell in web container"
	@echo "  docs      - Generate API documentation"
	@echo "  health    - Check application health"
	@echo "  ps        - Show container status"
	@echo "  build     - Build containers"
	@echo "  rebuild   - Rebuild containers (no cache)"
	@echo "  logs-all  - Show logs from all services"
	@echo "  logs-db   - Show database logs"
	@echo "  logs-redis- Show Redis logs"

# Setup & Development
setup:
	@echo "Setting up Store API..."
	docker compose up -d
	docker compose exec web bundle install
	docker compose exec web bundle exec rails db:create db:migrate db:seed
	@echo "Setup complete! API available at http://localhost:3002"

start:
	@echo "Starting Store API..."
	docker compose up -d
	@echo "Store API started at http://localhost:3002"

stop:
	@echo "Stopping Store API..."
	docker compose down

restart: stop start

logs:
	docker compose logs -f web

logs-all:
	docker compose logs -f

logs-db:
	docker compose logs -f db

logs-redis:
	docker compose logs -f redis

ps:
	docker compose ps

build:
	docker compose build

rebuild:
	docker compose build --no-cache

clean:
	@echo "Cleaning up containers and volumes..."
	docker compose down -v
	docker system prune -f

# Database
db-setup:
	docker compose exec web bundle exec rails db:create db:migrate db:seed

db-test-setup:
	@echo "Setting up test database..."
	docker compose exec -e RAILS_ENV=test web bundle exec rails db:create db:schema:load
	@echo "Test database ready!"
	@echo "Ensuring store_api database exists..."
	@docker compose exec db psql -U store_api -d postgres <<-EOSQL || true
		DO \$\$
		BEGIN
		    IF NOT EXISTS (SELECT FROM pg_database WHERE datname = 'store_api') THEN
		        CREATE DATABASE store_api;
		    END IF;
		END
		\$\$;
	EOSQL

db-reset:
	docker compose exec web bundle exec rails db:drop db:create db:migrate db:seed
	@echo "Ensuring store_api database exists..."
	@docker compose exec db psql -U store_api -d postgres <<-EOSQL || true
		DO \$\$
		BEGIN
		    IF NOT EXISTS (SELECT FROM pg_database WHERE datname = 'store_api') THEN
		        CREATE DATABASE store_api;
		    END IF;
		END
		\$\$;
	EOSQL

db-migrate:
	docker compose exec web bundle exec rails db:migrate

db-seed:
	docker compose exec web bundle exec rails db:seed

db-console:
	docker compose exec web bundle exec rails dbconsole

db-fix:
	@echo "Creating store_api database if it doesn't exist..."
	@docker compose exec db psql -U store_api -d postgres <<-EOSQL || true
		DO \$\$
		BEGIN
		    IF NOT EXISTS (SELECT FROM pg_database WHERE datname = 'store_api') THEN
		        CREATE DATABASE store_api;
		    END IF;
		END
		\$\$;
	EOSQL
	@echo "Database store_api is ready!"

# Code Quality
test:
	@echo "Running all tests..."
	docker compose exec web bundle exec rspec

test-auth:
	@echo "Running authentication tests..."
	docker compose exec web bundle exec rspec spec/services/auth spec/controllers/api/v1/auth_controller_spec.rb

test-fast:
	@echo "Running fast tests (excluding slow tests)..."
	docker compose exec web bundle exec rspec --tag ~slow

test-coverage:
	@echo "Running tests with coverage..."
	docker compose exec -e COVERAGE=true web bundle exec rspec

test-watch:
	@echo "Running tests in watch mode..."
	docker compose exec web bundle exec rspec --watch

test-single:
	@echo "Usage: make test-single FILE=spec/path/to/file_spec.rb"
	@if [ -z "$(FILE)" ]; then \
		echo "Error: FILE parameter required"; \
		echo "Example: make test-single FILE=spec/services/auth/auth_service_spec.rb"; \
		exit 1; \
	fi
	docker compose exec web bundle exec rspec $(FILE)

lint:
	docker compose exec web bundle exec rubocop

security:
	docker compose exec web bundle exec brakeman

format:
	docker compose exec web bundle exec rubocop --autocorrect

# Utilities
console:
	docker compose exec web bundle exec rails console

shell:
	docker compose exec web bash

docs:
	docker compose exec web bundle exec rails swagger:docs

health:
	@echo "Checking application health..."
	@curl -s http://localhost:3002/api/v1/health | jq . || echo "Health check failed"

# Development helpers
dev-setup: setup
	@echo "Development setup complete!"
	@echo "API: http://localhost:3002"
	@echo "Health: http://localhost:3002/api/v1/health"
	@echo "Docs: http://localhost:3002/api-docs"

quick-test:
	@echo "Running quick tests..."
	docker compose exec web bundle exec rails runner "puts 'Testing models...'; puts Discount.count; puts Promotion.count; puts 'All systems working!'"

# Production helpers
prod-build:
	docker compose -f docker-compose.yml -f docker-compose.prod.yml build

prod-deploy:
	docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d

# Maintenance
jwt-cleanup:
	docker compose exec web bundle exec rails jwt:cleanup

backup-db:
	@echo "Creating database backup..."
	docker compose exec db pg_dump -U store_api store_api_development > backup_$(shell date +%Y%m%d_%H%M%S).sql

restore-db:
	@echo "Restoring database from backup..."
	@read -p "Enter backup file name: " file; \
	docker compose exec -T db psql -U store_api store_api_development < $$file
