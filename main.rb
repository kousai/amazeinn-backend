require 'sinatra'
require 'slim'
require_relative 'models/init'
require_relative 'routes/init'
require_relative 'routes/constants'

use Rack::Session::Pool, :expire_after => 3600

get '/' do
  @brief_guests = "Here are #{Guest.count.to_s} guests, and #{Guest.count(:isreal => true).to_s} real guests!"
  @brief_messages = "Here are #{Message.count.to_s} messages!"
  @brief_contacts = "Here are #{Contact.count.to_s} contacts!"
  @brief_thumbs = "Here are #{Thumb.count.to_s} thumbs!"
  @brief_rooms = "Here are #{Room.count.to_s} Rooms, and #{Room.count(:isempty => true).to_s} empty rooms!"
  @isLogedIn = !session[:value].nil?
  slim :index
end

post '/admin/login' do
  _body = JSON.parse(request.body.read)
  if _body["account"] == "admin" && _body["password"] == "amazeinn"
    session[:value] = "admin"
    _guests = Guest.all
    _messages = Message.all
    _contacts = Contact.all
    _thumbs = Thumb.all
    _rooms = Room.all
    {guests: _guests, messages: _messages, contacts: _contacts, thumbs: _thumbs, rooms: _rooms}.to_json
  else
    400
  end
end

post '/admin/logout' do
  session.clear
end

post '/admin/new' do
  200
end

post '/admin/update' do
  200
end

post '/admin/delete' do
  200
end

post '/admin/refresh' do
  _guests = Guest.all
  _messages = Message.all
  _contacts = Contact.all
  _thumbs = Thumb.all
  _rooms = Room.all
  {guests: _guests, messages: _messages, contacts: _contacts, thumbs: _thumbs, rooms: _rooms}.to_json
end

post '/admin/drop' do
  _body = JSON.parse(request.body.read)
  case _body["schema"]
  when "Guest" then Guest.auto_migrate!
  when "Message" then Message.auto_migrate!
  when "Contact" then Contact.auto_migrate!
  when "Thumb" then Thumb.auto_migrate!
  when "Room" then Room.auto_migrate!
  when "Rand" then Constants.drop_rand()
  end
end

post '/admin/init' do
  _body = JSON.parse(request.body.read)
  case _body["type"]
  when "random" then init_random(_body["amount"])
  when "room" then init_room(_body["amount"])
  when "mock" then init_mock(_body["amount"])
  end
end
