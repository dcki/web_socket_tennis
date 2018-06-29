class GameController < ApplicationController
  def show
    redirect_to new_session_path unless current_user
  end
end
