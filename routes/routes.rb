require 'base64'
require 'json'
require_relative 'constants'
require_relative 'helpers'

get '/static/*/*/*.*' do
  _res = 'static/'
  _res << params['splat'][0] << '/' << params['splat'][1] << '/' << params['splat'][2] << '.' << params['splat'][3]
  send_file _res
end

options '/api/checkin' do
  _res = Constants::RESPONSE
  [204] + _res + [{}.to_json]
end

post '/api/checkin' do
  _body = JSON.parse(request.body.read)
  guest_create(_body)
end

options '/api/enter' do
  _res = Constants::RESPONSE
  [204] + _res + [{}.to_json]
end

post '/api/enter' do
  _body = JSON.parse(request.body.read)
  guest_login(_body)
end

options '/api/leave' do
  _res = Constants::RESPONSE
  [204] + _res + [{}.to_json]
end

post '/api/leave' do
  _header = JSON.parse(request.env.to_json)
  guest_leave(_header)
end

options '/api/checkout' do
  _res = Constants::RESPONSE
  [204] + _res + [{}.to_json]
end

post '/api/checkout' do
  _body = JSON.parse(request.body.read)
  _header = JSON.parse(request.env.to_json)
  guest_delete(_header, _body["password"])
end

options '/api/refresh' do
  _res = Constants::RESPONSE
  [204] + _res + [{}.to_json]
end

post '/api/refresh' do
  _header = JSON.parse(request.env.to_json)
  token_update(_header)
end

options '/api/info' do
  _res = Constants::RESPONSE
  [204] + _res + [{}.to_json]
end

post '/api/info' do
  _res = Constants::RESPONSE
  if params["file"].nil?
    _body = JSON.parse(request.body.read)
  else
    _body = params
  end
  _header = JSON.parse(request.env.to_json)
  _guest = Guest.first(:_id => Base64.decode64(_header["HTTP_CLIENT_ID"]).to_i)
  if token_compare(_guest, _header["HTTP_ACCESS_TOKEN"])
    case_guest_info(_body, _header)
  else
    [401] + _res + [{}.to_json]
  end
end