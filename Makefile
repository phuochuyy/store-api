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

# Setup & Development
setup:
	@echo "Setting up Store API..."
	docker compose up -d
	docker compose exec web bundle install
	docker compose exec web bundle exec rails db:create db:migrate db:seed
	@echo "Setup complete! API available at http://localhost:3000"

start:
	@echo "Starting Store API..."
	docker compose up -d
	@echo "Store API started at http://localhost:3000"

stop:
	@echo "Stopping Store API..."
	docker compose down

restart: stop start

logs:
	docker compose logs -f web

clean:
	@echo "Cleaning up containers and volumes..."
	docker compose down -v
	docker system prune -f

# Database
db-setup:
	docker compose exec web bundle exec rails db:create db:migrate db:seed

db-reset:
	docker compose exec web bundle exec rails db:drop db:create db:migrate db:seed

db-migrate:
	docker compose exec web bundle exec rails db:migrate

db-seed:
	docker compose exec web bundle exec rails db:seed

db-console:
	docker compose exec web bundle exec rails dbconsole

# Code Quality
test:
	docker compose exec web bundle exec rspec

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
	@curl -s http://localhost:3000/api/v1/health | jq . || echo "Health check failed"

# Development helpers
dev-setup: setup
	@echo "Development setup complete!"
	@echo "API: http://localhost:3000"
	@echo "Health: http://localhost:3000/api/v1/health"
	@echo "Docs: http://localhost:3000/api-docs"

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
	docker compose exec db pg_dump -U postgres store_api_development > backup_$(shell date +%Y%m%d_%H%M%S).sql

restore-db:
	@echo "Restoring database from backup..."
	@read -p "Enter backup file name: " file; \
	docker compose exec -T db psql -U postgres store_api_development < $$file
