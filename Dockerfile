# Development Dockerfile
FROM ruby:3.4.5-slim

# Install system dependencies
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
    build-essential \
    git \
    libpq-dev \
    libvips \
    postgresql-client \
    curl \
    libyaml-dev \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /rails

# Set environment variables
ENV RAILS_ENV=development
ENV BUNDLE_PATH=/usr/local/bundle
ENV BUNDLE_WITHOUT=""

# Copy Gemfile and install gems
COPY Gemfile Gemfile.lock ./
RUN bundle install

# Copy application code
COPY . .

# Create necessary directories
RUN mkdir -p tmp/pids log

# Expose port
EXPOSE 3000

# Default command
CMD ["./bin/rails", "server", "-b", "0.0.0.0"]
