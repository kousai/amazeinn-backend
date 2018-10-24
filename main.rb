require 'sinatra'
require_relative 'models/init'
require_relative 'routes/init'

get '/' do
  _index = ""
  _brief_summary = "<h1>Brief Summary</h1>"
  _brief_guests = "<p>Here are #{Guest.count.to_s} guests, and #{Guest.count(:isreal => true).to_s} real guests!</p>"
  _brief_messages = "<p>Here are #{Message.count.to_s} messages!</p>"
  _brief_contacts = "<p>Here are #{Contact.count.to_s} contacts!</p>"
  _brief_thumbs = "<p>Here are #{Thumb.count.to_s} thumbs!</p>"
  _brief_rooms = "<p>Here are #{Room.count.to_s} Rooms, and #{Room.count(:isempty => true).to_s} empty rooms!</p>"
  _brief_summary << _brief_guests << _brief_messages << _brief_contacts << _brief_thumbs << _brief_rooms
  _list_guests = "<h2>List of Guests</h2><table border='1'><tr><th>id</th><th>name</th><th>gender</th></tr>"
  _guests = Guest.all
  _guests.each do |guest|
    _list_guests << "<tr><td>#{guest._id.to_s}</td><td>#{guest.name}</td><td>#{guest.gender}</td></tr>"
  end
  _list_guests << "</table>"
  _index << _brief_summary <<_list_guests
end
