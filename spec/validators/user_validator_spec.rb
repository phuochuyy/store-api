require 'rails_helper'

RSpec.describe UserValidator, type: :validator do
  describe 'validations' do
    context 'with valid attributes' do
      it 'is valid' do
        validator = UserValidator.new(
          name: 'John Doe',
          email: 'john@example.com',
          password: 'password123',
          password_confirmation: 'password123',
          role: 'customer'
        )
        expect(validator).to be_valid
      end
    end

    context 'name validation' do
      it 'is invalid without name' do
        validator = UserValidator.new(
          email: 'john@example.com',
          password: 'password123',
          password_confirmation: 'password123',
          role: 'customer'
        )
        expect(validator).not_to be_valid
        expect(validator.errors[:name]).to include("can't be blank")
      end

      it 'is invalid with name too short' do
        validator = UserValidator.new(
          name: 'A',
          email: 'john@example.com',
          password: 'password123',
          password_confirmation: 'password123',
          role: 'customer'
        )
        expect(validator).not_to be_valid
        expect(validator.errors[:name]).to include('is too short (minimum is 2 characters)')
      end

      it 'is invalid with name too long' do
        validator = UserValidator.new(
          name: 'A' * 101,
          email: 'john@example.com',
          password: 'password123',
          password_confirmation: 'password123',
          role: 'customer'
        )
        expect(validator).not_to be_valid
        expect(validator.errors[:name]).to include('is too long (maximum is 100 characters)')
      end
    end

    context 'email validation' do
      it 'is invalid without email' do
        validator = UserValidator.new(
          name: 'John Doe',
          password: 'password123',
          password_confirmation: 'password123',
          role: 'customer'
        )
        expect(validator).not_to be_valid
        expect(validator.errors[:email]).to include("can't be blank")
      end

      it 'is invalid with invalid email format' do
        validator = UserValidator.new(
          name: 'John Doe',
          email: 'invalid-email',
          password: 'password123',
          password_confirmation: 'password123',
          role: 'customer'
        )
        expect(validator).not_to be_valid
        expect(validator.errors[:email]).to include('is invalid')
      end

      it 'is valid with valid email format' do
        validator = UserValidator.new(
          name: 'John Doe',
          email: 'john.doe@example.com',
          password: 'password123',
          password_confirmation: 'password123',
          role: 'customer'
        )
        expect(validator).to be_valid
      end
    end

    context 'password validation' do
      it 'is invalid without password' do
        validator = UserValidator.new(
          name: 'John Doe',
          email: 'john@example.com',
          password_confirmation: 'password123',
          role: 'customer'
        )
        expect(validator).not_to be_valid
        expect(validator.errors[:password]).to include("can't be blank")
      end

      it 'is invalid with password too short' do
        validator = UserValidator.new(
          name: 'John Doe',
          email: 'john@example.com',
          password: '12345',
          password_confirmation: '12345',
          role: 'customer'
        )
        expect(validator).not_to be_valid
        expect(validator.errors[:password]).to include('is too short (minimum is 6 characters)')
      end

      it 'is valid with password at minimum length' do
        validator = UserValidator.new(
          name: 'John Doe',
          email: 'john@example.com',
          password: '123456',
          password_confirmation: '123456',
          role: 'customer'
        )
        expect(validator).to be_valid
      end
    end

    context 'password_confirmation validation' do
      it 'is invalid without password_confirmation' do
        validator = UserValidator.new(
          name: 'John Doe',
          email: 'john@example.com',
          password: 'password123',
          role: 'customer'
        )
        expect(validator).not_to be_valid
        expect(validator.errors[:password_confirmation]).to include("can't be blank")
      end

      it 'is invalid when passwords do not match' do
        validator = UserValidator.new(
          name: 'John Doe',
          email: 'john@example.com',
          password: 'password123',
          password_confirmation: 'different123',
          role: 'customer'
        )
        expect(validator).not_to be_valid
        expect(validator.errors[:password_confirmation]).to include("doesn't match Password")
      end

      it 'is valid when passwords match' do
        validator = UserValidator.new(
          name: 'John Doe',
          email: 'john@example.com',
          password: 'password123',
          password_confirmation: 'password123',
          role: 'customer'
        )
        expect(validator).to be_valid
      end
    end

    context 'role validation' do
      it 'is invalid with invalid role' do
        validator = UserValidator.new(
          name: 'John Doe',
          email: 'john@example.com',
          password: 'password123',
          password_confirmation: 'password123',
          role: 'invalid_role'
        )
        expect(validator).not_to be_valid
        expect(validator.errors[:role]).to include('is not included in the list')
      end

      it 'is valid with admin role' do
        validator = UserValidator.new(
          name: 'John Doe',
          email: 'john@example.com',
          password: 'password123',
          password_confirmation: 'password123',
          role: 'admin'
        )
        expect(validator).to be_valid
      end

      it 'is valid with customer role' do
        validator = UserValidator.new(
          name: 'John Doe',
          email: 'john@example.com',
          password: 'password123',
          password_confirmation: 'password123',
          role: 'customer'
        )
        expect(validator).to be_valid
      end
    end
  end

  describe 'attributes' do
    it 'has all required attributes' do
      validator = UserValidator.new
      expect(validator).to respond_to(:name)
      expect(validator).to respond_to(:email)
      expect(validator).to respond_to(:password)
      expect(validator).to respond_to(:password_confirmation)
      expect(validator).to respond_to(:role)
    end
  end
end
