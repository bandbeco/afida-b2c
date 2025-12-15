# frozen_string_literal: true

class AccountsController < ApplicationController
  before_action :require_authentication

  def show
    @user = Current.user
  end

  def update
    @user = Current.user

    if @user.update(user_params)
      redirect_to account_path, notice: "Account updated successfully."
    else
      render :show, status: :unprocessable_entity
    end
  end

  private

  def user_params
    params.expect(user: [
      :first_name,
      :last_name,
      :password,
      :password_confirmation
    ])
  end
end
