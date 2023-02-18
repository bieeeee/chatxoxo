class ChatroomsController < ApplicationController
  def new
    @chatroom = Chatroom.new
  end

  def create
    @chatroom = Chatroom.new(params[:id])
  end

  def show
    @chatroom = Chatroom.find(params[:id])
    @message = Message.new
  end
end
