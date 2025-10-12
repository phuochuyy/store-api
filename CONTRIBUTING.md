# Contributing to Store API

Thank you for your interest in contributing to Store API! This document provides guidelines and information for contributors.

## 🚀 Getting Started

### Prerequisites
- Ruby 3.3.9+
- PostgreSQL 15+
- Docker & Docker Compose
- Git

### Development Setup

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd store-api
   ```

2. **Start with Docker**
   ```bash
   docker compose up -d
   ```

3. **Setup database**
   ```bash
   docker compose exec web bundle exec rails db:create db:migrate db:seed
   ```

4. **Verify setup**
   ```bash
   curl http://localhost:3000/api/v1/health
   ```

## 📋 Development Guidelines

### Code Style
- Follow Ruby style guide
- Use RuboCop for code quality
- Write clean, readable code
- Add comments for complex logic

### Git Workflow
1. Create a feature branch from `main`
2. Make your changes
3. Write/update tests if applicable
4. Run code quality checks
5. Submit a pull request

### Branch Naming
- `feature/description` - New features
- `bugfix/description` - Bug fixes
- `hotfix/description` - Critical fixes
- `refactor/description` - Code refactoring

### Commit Messages
Use conventional commit format:
```
type(scope): description

[optional body]

[optional footer]
```

Types: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`

## 🧪 Testing

### Running Tests
```bash
# Run all tests
docker compose exec web bundle exec rspec

# Run specific test file
docker compose exec web bundle exec rspec spec/models/user_spec.rb

# Run with coverage
docker compose exec web COVERAGE=true bundle exec rspec
```

### Test Guidelines
- Write tests for new features
- Maintain test coverage above 80%
- Use descriptive test names
- Follow AAA pattern (Arrange, Act, Assert)

## 🔍 Code Quality

### RuboCop
```bash
# Check code style
docker compose exec web bundle exec rubocop

# Auto-correct issues
docker compose exec web bundle exec rubocop --autocorrect
```

### Security
```bash
# Run security scan
docker compose exec web bundle exec brakeman
```

## 📚 Documentation

### API Documentation
- Update Swagger documentation for new endpoints
- Include request/response examples
- Document error codes and messages

### Code Documentation
- Add comments for complex business logic
- Document public methods
- Update README for new features

## 🐛 Bug Reports

When reporting bugs, please include:
- Steps to reproduce
- Expected behavior
- Actual behavior
- Environment details
- Screenshots/logs if applicable

## 💡 Feature Requests

For feature requests, please:
- Describe the feature clearly
- Explain the use case
- Consider implementation complexity
- Check for existing similar requests

## 🔒 Security

- Never commit sensitive data (passwords, API keys)
- Use environment variables for configuration
- Follow security best practices
- Report security issues privately

## 📝 Pull Request Process

1. **Fork the repository**
2. **Create your feature branch**
3. **Make your changes**
4. **Add tests if applicable**
5. **Run quality checks**
6. **Update documentation**
7. **Submit pull request**

### PR Requirements
- [ ] Code follows style guidelines
- [ ] Tests pass
- [ ] Documentation updated
- [ ] No security issues
- [ ] Performance impact considered

## 🏗️ Architecture Guidelines

### Service Layer
- Keep business logic in services
- Services should be stateless
- Use dependency injection
- Handle errors gracefully

### Models
- Keep models focused on data
- Use validations appropriately
- Define proper associations
- Use scopes for queries

### Controllers
- Keep controllers thin
- Use before_actions appropriately
- Return proper HTTP status codes
- Handle errors consistently

### API Design
- Follow RESTful conventions
- Use proper HTTP methods
- Include pagination for lists
- Provide meaningful error messages

## 🚀 Deployment

### Environment Variables
- Use `.env.example` as template
- Never commit `.env` files
- Document required variables

### Database Migrations
- Always create reversible migrations
- Test migrations on sample data
- Consider performance impact
- Add indexes for new queries

## 📞 Support

- Create issues for bugs and feature requests
- Use discussions for questions
- Check existing documentation first
- Be respectful and constructive

## 📄 License

By contributing, you agree that your contributions will be licensed under the same license as the project.

---

Thank you for contributing to Store API! 🎉
