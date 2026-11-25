require 'rails_helper'

RSpec.describe Api::Authorization, type: :controller do
  # The actions deliberately do NOT check `performed?` after authorize!/admin_only!:
  # a denial must stop the action by itself. `after_authorization` stands in for the
  # action's real work (saving a record, changing a status...) and must never run on a 403.
  controller(ApplicationController) do
    include Api::Authentication
    include Api::Authorization

    before_action(only: :test_before_action_authorize) { authorize!(:show, test_resource) }

    def test_authorize_action
      authorize!(:show, test_resource)
      after_authorization
      render json: { success: true }
    end

    def test_authorize_class_action
      authorize!(:create, ProductVariant)
      after_authorization
      render json: { success: true }
    end

    def test_before_action_authorize
      after_authorization
      render json: { success: true }
    end

    def test_admin_only_action
      admin_only!
      after_authorization
      render json: { success: true }
    end

    private

    def test_resource
      @test_resource ||= create(:user)
    end

    def after_authorization; end
  end

  let(:user) { create(:user) }
  let(:admin_user) { create(:user, :admin) }

  def sign_in_as(account)
    request.headers['Authorization'] = "Bearer #{generate_jwt_token(account)}"
  end

  before do
    routes.draw do
      get 'test_authorize_action' => 'anonymous#test_authorize_action'
      get 'test_authorize_class_action' => 'anonymous#test_authorize_class_action'
      get 'test_before_action_authorize' => 'anonymous#test_before_action_authorize'
      get 'test_admin_only_action' => 'anonymous#test_admin_only_action'
    end
    allow(controller).to receive(:after_authorization)
  end

  shared_examples 'a forbidden request' do |message|
    it 'responds 403 and stops the action' do
      expect(response).to have_http_status(:forbidden)
      expect(response.parsed_body).to include('success' => false, 'message' => message)
      expect(controller).not_to have_received(:after_authorization)
    end
  end

  shared_examples 'an allowed request' do
    it 'runs the action' do
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['success']).to be true
      expect(controller).to have_received(:after_authorization)
    end
  end

  describe '#authorize!' do
    context 'when the user owns the resource' do
      before do
        sign_in_as(user)
        allow(controller).to receive(:test_resource).and_return(user)
        get :test_authorize_action
      end

      it_behaves_like 'an allowed request'
    end

    context 'when the user is an admin' do
      before do
        sign_in_as(admin_user)
        allow(controller).to receive(:test_resource).and_return(create(:user))
        get :test_authorize_action
      end

      it_behaves_like 'an allowed request'
    end

    context 'when the policy denies the action' do
      before do
        sign_in_as(user)
        allow(controller).to receive(:test_resource).and_return(create(:user))
        get :test_authorize_action
      end

      it_behaves_like 'a forbidden request', 'Access denied'
    end

    context 'when called from a before_action' do
      before { sign_in_as(user) }

      context 'and the policy denies the action' do
        before do
          allow(controller).to receive(:test_resource).and_return(create(:user))
          get :test_before_action_authorize
        end

        it_behaves_like 'a forbidden request', 'Access denied'
      end

      context 'and the policy allows the action' do
        before do
          allow(controller).to receive(:test_resource).and_return(user)
          get :test_before_action_authorize
        end

        it_behaves_like 'an allowed request'
      end
    end

    context 'with a model class instead of a record' do
      context 'when the policy allows the action' do
        before do
          sign_in_as(admin_user)
          get :test_authorize_class_action
        end

        it_behaves_like 'an allowed request'
      end

      context 'when the policy denies the action' do
        before do
          sign_in_as(user)
          get :test_authorize_class_action
        end

        it_behaves_like 'a forbidden request', 'Access denied'
      end
    end

    context 'when no policy exists for the resource' do
      before do
        sign_in_as(user)
        allow(controller).to receive(:test_resource).and_return('string_resource')
        get :test_authorize_action
      end

      it_behaves_like 'a forbidden request', 'Authorization policy not found'
    end

    context 'when the user is not authenticated' do
      before { get :test_authorize_action }

      it 'responds 401 and stops the action' do
        expect(response).to have_http_status(:unauthorized)
        expect(controller).not_to have_received(:after_authorization)
      end
    end
  end

  describe '#admin_only!' do
    context 'with an admin' do
      before do
        sign_in_as(admin_user)
        get :test_admin_only_action
      end

      it_behaves_like 'an allowed request'
    end

    context 'with a customer' do
      before do
        sign_in_as(user)
        get :test_admin_only_action
      end

      it_behaves_like 'a forbidden request', 'Admin access required'
    end

    context 'when the user is not authenticated' do
      before { get :test_admin_only_action }

      it 'responds 401 and stops the action' do
        expect(response).to have_http_status(:unauthorized)
        expect(controller).not_to have_received(:after_authorization)
      end
    end
  end
end
