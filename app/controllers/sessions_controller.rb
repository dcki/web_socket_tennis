class SessionsController < ApplicationController
  # This is just here in case someone is sitting on the form after getting a
  # validation error and submits what is in the address bar, which would make
  # a request to this action.
  def index
    redirect_to action: :new
  end

  def new
    @user = User.new
  end

  # THIS IS PROBABLY NOT SECURE.
  # If and when that matters, implement a real authentication solution.
  def create
    @user = User.create(name: params[:user][:name])
    if @user.valid?
      User.set_encrypted_session_id(cookies, @user.id)
      redirect_to root_path
    else
      flash.now[:error] = @user.errors.full_messages.join(', ')
      render :new
    end
  end

  def destroy
    current_user.try(:destroy)
    redirect_to root_path
  end
end
