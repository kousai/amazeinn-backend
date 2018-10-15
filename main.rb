require 'sinatra'
require_relative 'models/init'
require_relative 'routes/init'

get '/' do
  _guests = Guest.all
  _brief_summary = "<p>Here are #{Guest.count.to_s} guests, and #{Guest.count(:isreal => true).to_s} real guests!</p>" +
                   "<p>Here are #{Message.count.to_s} messages!</p>" +
                   "<p>Here are #{Contact.count.to_s} contacts!</p>" +
                   "<p>Here are #{Room.count.to_s} Rooms, and #{Room.count(:isempty => true).to_s} empty rooms!</p>"
  _list_guests = "<table border='1'><tr><th>id</th><th>name</th><th>gender</th></tr>"
  _guests.each do |guest|
    _list_guests += "<tr><td>#{guest._id.to_s}</td><td>#{guest.name}</td><td>#{guest.gender}</td></tr>"
  end
  _list_guests += "</table>"
  _index = "<h1>Brief Summary</h1>" + _brief_summary +
           "<h2>List of Guests</h2>" + _list_guests
end