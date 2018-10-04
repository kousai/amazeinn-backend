require 'bcrypt'
require 'json'
require 'jwt'
require 'base64'
require_relative 'support'
require_relative 'helpers'

class App < Sinatra::Base
  get '/static/*/*/*.*' do
    params['splat']
    send_file 'static/' + params['splat'][0] + '/' + params['splat'][1] + '/' + params['splat'][2] + '.' + params['splat'][3]
  end
  
  options '/api/checkin' do
    @res = Something::RESPONSE
    [204] + @res + [{}.to_json]
  end
  
  post '/api/checkin' do
    @body = JSON.parse(request.body.read)
    guest_create(@body)
  end
  
  options '/api/enter' do
    @res = Something::RESPONSE
    [204] + @res + [{}.to_json]
  end
  
  post '/api/enter' do
    @body = JSON.parse(request.body.read)
    guest_login(@body)
  end
  
  options '/api/leave' do
    @res = Something::RESPONSE
    [204] + @res + [{}.to_json]
  end
  
  post '/api/leave' do
    @header = JSON.parse(request.env.to_json)
    guest_leave(@header)
  end
  
  options '/api/checkout' do
    @res = Something::RESPONSE
    [204] + @res + [{}.to_json]
  end
  
  post '/api/checkout' do
    @body = JSON.parse(request.body.read)
    @header = JSON.parse(request.env.to_json)
    guest_delete(@header, @body["password"])
  end
  
  options '/api/refresh' do
    @res = Something::RESPONSE
    [204] + @res + [{}.to_json]
  end
  
  post '/api/refresh' do
    @header = JSON.parse(request.env.to_json)
    token_update(@header)
  end
  
  options '/api/info' do
    @res = Something::RESPONSE
    [204] + @res + [{}.to_json]
  end
  
  post '/api/info' do
    @res = Something::RESPONSE
    if params["file"].nil?
      @body = JSON.parse(request.body.read)
    else
      @body = params
    end
    @header = JSON.parse(request.env.to_json)
    @guest = Guest.first(:_id => Base64.decode64(@header["HTTP_CLIENT_ID"]).to_i)
    if token_compare(@guest, @header["HTTP_ACCESS_TOKEN"])
      case_guest_info(@body, @header)
    else
      [401] + @res + [{}.to_json]
    end
  end
end