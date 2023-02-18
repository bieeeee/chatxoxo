Problem
Sometimes, web applications need real-time features

HTTP
HTTP is a request / response cycle protocol

HTTP Protocol

The request has to be triggered by the client

Real-time
In a chat app for example, several clients need to be updated in real-time with incoming messages



We don’t want to trigger HTTP requests every second to fake real-time

WebSocket
Unlike HTTP, WebSocket is bidirectional

WebSocket protocol

A message created on the server can be broadcasted to subscribed clients (browsers)

Lets build a chat
Boilerplate
Start from Le Wagon’s Rails Devise Template :

rails new \
  -d postgresql \
  -j webpack \
  -m https://raw.githubusercontent.com/lewagon/rails-templates/master/devise.rb \
  rails-action-cable-chat

cd rails-action-cable-chat
rails g model Chatroom name
rails g model Message content chatroom:references user:references
rails g migration AddNicknameToUsers nickname
rails db:migrate
Chatroom model
# app/models/chatroom.rb
class Chatroom < ApplicationRecord
  has_many :messages
end
# rails c
Chatroom.create(name: "general")
User.create(email: "sebastien@lewagon.org", nickname: "Sebastien", password: "123456")
User.create(email: "boris@lewagon.org", nickname: "Boris", password: "123456")
Chatrooms route and controller
# config/routes.rb
# [...]
resources :chatrooms, only: :show
rails g controller chatrooms
# app/controllers/chatrooms_controller.rb
class ChatroomsController < ApplicationController
  def show
    @chatroom = Chatroom.find(params[:id])
  end
end
Chatrooms show view
<!-- app/views/chatrooms/show.html.erb -->
<div class="container chatroom">
  <h1>#<%= @chatroom.name %></h1>

  <div class="messages">
    <% @chatroom.messages.each do |message| %>
      <div id="message-<%= message.id %>">
        <small>
          <strong><%= message.user.nickname %></strong>
          <i><%= message.created_at.strftime("%a %b %e at %l:%M %p") %></i>
        </small>
        <p><%= message.content %></p>
      </div>
    <% end %>
  </div>
</div>

Update the navbar
Update the logo link to point to the root path:

<!-- app/views/shared/_navbar.html.erb -->
<!-- [...] -->
<%= link_to root_path, class: "navbar-brand" do %>
  <%= image_tag "https://raw.githubusercontent.com/lewagon/fullstack-images/master/uikit/logo.png" %>
<% end %>
And replace the avatar by current_user.nickname to see the context:

<!-- app/views/shared/_navbar.html.erb -->
<!-- [...] -->
<% if user_signed_in? %>
  <li class="nav-item dropdown">
    <a class="nav-link" href="#" data-bs-toggle="dropdown"><%= current_user.nickname %></a>
    <div class="dropdown-menu dropdown-menu-end" aria-labelledby="navbarDropdown">
      <%= link_to "Log out", destroy_user_session_path, data: {turbo_method: :delete}, class: "dropdown-item" %>
    </div>
  </li>
<% else %>
Add some style
curl https://gist.githubusercontent.com/dmilon/3db26308391f84b786ae6886a68897ae/raw/5aa85b85f6436794106962c1f3c088b99743f8d8/_chatroom.scss \
  > app/assets/stylesheets/components/_chatroom.scss
Don’t forget to @import "chatroom"; in components/_index.scss

Launch the app
rails s
yarn build --watch


Sign in with 2 different users using 2 browsers (or one private window)



Go to localhost:3000/chatrooms/1 🚀

Messages route and controller
# config/routes.rb
# [...]
resources :chatrooms, only: :show do
  resources :messages, only: :create
end
rails g controller messages
Chatrooms show view
# app/controllers/chatrooms_controller.rb
# [...]
def show
  @chatroom = Chatroom.find(params[:id])
  @message = Message.new
end
<!-- app/views/chatrooms/show.html.erb -->
<!-- [...] -->
<%= simple_form_for [@chatroom, @message],
  html: {class: "d-flex"} do |f|
%>
  <%= f.input :content,
    label: false,
    placeholder: "Message ##{@chatroom.name}",
    wrapper_html: {class: "flex-grow-1"}
  %>
  <%= f.submit "Send", class: "btn btn-primary mb-3" %>
<% end %>
Messages create action
# app/controllers/messages_controller.rb
class MessagesController < ApplicationController
  def create
    @chatroom = Chatroom.find(params[:chatroom_id])
    @message = Message.new(message_params)
    @message.chatroom = @chatroom
    @message.user = current_user
    if @message.save
      redirect_to chatroom_path(@chatroom)
    else
      render "chatrooms/show", status: :unprocessable_entity
    end
  end

  private

  def message_params
    params.require(:message).permit(:content)
  end
end
Testing
Create a message with Seb in a window.



Problem: Boris has to refresh to see it

Action Cable
Let’s set up Action Cable in 3 steps 😎

1. Generate the channel
HTTP protocol

2. Subscribe each client
HTTP protocol

3. Broadcast data in the channel
HTTP protocol

Install Action Cable
yarn add @rails/actioncable
Generate the channel
rails g channel Chatroom
Make the channel specific to 1 chatroom:

# app/channels/chatroom_channel.rb
class ChatroomChannel < ApplicationCable::Channel
  def subscribed
    chatroom = Chatroom.find(params[:id])
    stream_for chatroom
  end
end
Create a Stimulus controller
rails generate stimulus chatroom_subscription
// app/javascript/controllers/chatroom_subscription_controller.js
import { Controller } from "@hotwired/stimulus"
import { createConsumer } from "@rails/actioncable"

export default class extends Controller {
  static values = { chatroomId: Number }
  static targets = ["messages"]

  connect() {
    console.log(`Subscribe to the chatroom with the id ${this.chatroomIdValue}.`)
  }
}

chatroomIdValue is the id of the chatroom we are going to subscribe to.

Connect it to your message list
<!-- app/views/chatrooms/show.html.erb -->
<div class="container chatroom"
  data-controller="chatroom-subscription"
  data-chatroom-subscription-chatroom-id-value="<%= @chatroom.id %>"
>
  <h1>#<%= @chatroom.name %></h1>

  <div class="messages" data-chatroom-subscription-target="messages">
  <!-- [...] -->
Subscribe each client
// app/javascript/controllers/chatroom_subscriptions_controller.js
//[...]
  connect() {
    this.channel = createConsumer().subscriptions.create(
      { channel: "ChatroomChannel", id: this.chatroomIdValue },
      { received: data => console.log(data) }
    )
    console.log(`Subscribed to the chatroom with the id ${this.chatroomIdValue}.`)
  }
received stores the function which is called when data is broadcasted in the channel.

Refactor the message into a partial
<!-- app/views/chatrooms/show.html.erb -->
<!-- [...] -->
<div class="messages" data-chatroom-subscription-target="messages">
  <% @chatroom.messages.each do |message| %>
    <%= render "messages/message", message: message %>
  <% end %>
</div>
<!-- app/views/messages/_message.html.erb -->
<div id="message-<%= message.id %>">
  <small>
    <strong><%= message.user.nickname %></strong>
    <i><%= message.created_at.strftime("%a %b %e at %l:%M %p") %></i>
  </small>
  <p><%= message.content %></p>
</div>
Broadcast each new message
In the create action, replace the if @message.save block:

# app/controllers/messages_controller.rb
# [...]
if @message.save
  ChatroomChannel.broadcast_to(
    @chatroom,
    render_to_string(partial: "message", locals: {message: @message})
  )
  head :ok
else
Testing
Open the console in Seb’s tab and post a message from Boris

Insert the message
In the received callback, insert the new message in the DOM:

// app/javascript/controllers/chatroom_subscriptions_controller.js
// [...]
received: data => this.messagesTarget.insertAdjacentHTML("beforeend", data)
Scroll down
In the received callback, call #insertMessageAndScrollDown()

// app/javascript/controllers/chatroom_subscriptions_controller.js
// [...]
received: data => this.#insertMessageAndScrollDown(data)
// [...]

#insertMessageAndScrollDown(data) {
  this.messagesTarget.insertAdjacentHTML("beforeend", data)
  this.messagesTarget.scrollTo(0, this.messagesTarget.scrollHeight)
}
private method in JavaScript are prepend with a #

Reset the form
For the message sender only

We want to reset the form after the message has been sent:

<!-- app/views/chatrooms/show.html.erb -->
<!-- [...] -->
<%= simple_form_for [@chatroom, @message],
  html: { data: { action: "turbo:submit-end->chatroom-subscription#resetForm" }, class: "d-flex" } do |f|
%>
// app/javascript/controllers/chatroom_subscriptions_controller.js
// [...]
resetForm(event) {
  event.target.reset()
}
The turbo:submit-end event is triggered after the form submits, so for the sender only.

Unsubscribe from the channel
// app/javascript/controllers/chatroom_subscriptions_controller.js
//[...]
disconnect() {
  console.log("Unsubscribed from the chatroom")
  this.channel.unsubscribe()
}
The disconnect() method is called when the controller disappears from the DOM

At this moment, we unsubscribe from the channel.

Have a look at the logs!
