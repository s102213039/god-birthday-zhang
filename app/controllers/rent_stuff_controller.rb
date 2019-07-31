require 'line/bot'
class RentStuffController < ApplicationController
  #before_action :authenticate_user!

  # GET /push_messages/new
  def new
  end

  # POST /push_messages
  def create
    text = params[:text]
    
    redirect_to '/push_messages/new'
  end
  
end