# frozen_string_literal: true
module Admin
  class UsersController < BaseController
    before_action :set_user, only: [:show, :edit, :update, :destroy]

    def index
      @users = User.all.order(created_at: :desc)
    end

    def show
    end

    def edit
    end

    def update
      if @user.update(user_params)
        redirect_to admin_user_path(@user), notice: "User updated successfully."
      else
        render "admin/users/edit", status: :unprocessable_content
      end
    end

    def destroy
      @user.destroy
      redirect_to admin_users_path, notice: "User deleted successfully."
    end

    private

    def set_user
      @user = User.find(params[:id])
    end

    def user_params
      permitted = params.expect(user: [:email])

      # Only allow admin role changes with explicit authorization
      # Prevent self-demotion which could lock out all admins
      if params[:user][:admin].present? && @user != current_user
        permitted[:admin] = params[:user][:admin]
      end

      permitted
    end
  end
end
