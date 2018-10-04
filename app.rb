require 'sinatra/base'

class App < Sinatra::Base
  get '/' do
    @guests = Guest.all
    @brief_summary = '<p>Here are ' + Guest.count.to_s + ' guests, and ' +
                     Guest.count(:isreal => true).to_s + ' real guests!</p>' +
                     '<p>Here are ' + Message.count.to_s + ' messages!</p>' +
                     '<p>Here are ' + Contact.count.to_s + ' contacts!</p>' +
                     '<p>Here are ' + Room.count.to_s + ' Rooms, and ' + 
                     Room.count(:isempty => true).to_s + ' empty rooms!</p>'
    @list_guests = '<table border="1"><tr><th>id</th><th>name</th><th>gender</th></tr>'
    @guests.each do |guest|
      @list_guests += '<tr><td>' + guest._id.to_s + '</td><td>' + guest.name + '</td><td>' + guest.gender + '</td></tr>'
    end
    @list_guests += '</table>'
    @index = '<h1>Brief Summary</h1>' + @brief_summary +
             '<h2>List of Guests</h2>' + @list_guests
  end
end

require_relative 'models/init'
require_relative 'routes/init'

App.run!