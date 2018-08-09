require 'net/http'
require 'uri'
require 'json'

MOCK_GUEST = '{"name":"look","password":"2222222"}'

MOCK_REQUEST = 'upload-file'

#edit_password
#MOCK_INSTS = {"old_password" => "3333333", "new_password" => "1111111"}

#edit_profile
#MOCK_INSTS = {"gender" => "male"}

#upload_file
MOCK_INSTS = {"action" => "avatar", "filename" => "a.jpg", "tempfile" => "xxxxxxx"}

#send_message
#MOCK_INSTS = {"message" => "Hello world!"}

#knock_door
#MOCK_INSTS = {"name" => "test"}

#follow_guest
#MOCK_INSTS = {"name" => "test"}

#unfollow_guest
#MOCK_INSTS = {"name" => "test"}

#like_message
#MOCK_INSTS = {"message_id" => 1}

#dislike_message
#MOCK_INSTS = {"message_id" => 2}

MOCK_CLIENT_ID = 'Nw==\n'

MOCK_REFRESH_TOKEN = 'eyJhbGciOiJIUzI1NiJ9.eyJndWVzdCI6Im1vY2siLCJ0aW1lIjoiMTUzMzYzNjA1NSJ9.vWaLK9GD3S3dJxm1JcFL3vbWYmb9mIDH1PrLsWD8a0U'

MOCK_ACCESS_TOKEN = 'eyJhbGciOiJIUzI1NiJ9.eyJyZWZyZXNoIjoiMTUzMzYzNjA1NSIsInRpbWUiOiIxNTMzNjM2MDU1In0.NoG0Ul78f28jcPLQfzzkZR8Y8MsfE0LVKekeSKN5Z_Y'

def create_agent
    uri = URI('http://localhost:4567/api/info')
    http = Net::HTTP.new(uri.host, uri.port)
    req = Net::HTTP::Post.new(uri.path, 'Content-Type' => 'application/json')
    req.initialize_http_header({
        "CLIENT_ID" => MOCK_CLIENT_ID,
        "REFRESH_TOKEN" => MOCK_REFRESH_TOKEN,
        "ACCESS_TOKEN" => MOCK_ACCESS_TOKEN,
        "REQUEST" => MOCK_REQUEST,
        "ACTION" => "avatar"
    })
    req.body = {name: "mock", password: "1111111", instruction: MOCK_INSTS}.to_json
    res = http.request(req)
    puts "response #{res.body}"
rescue => e
    puts "failed #{e}"
end

#create_agent

file_name = "Other.png"
binary_file = File.open(file_name, "rb")
begin
  data = { filename: file_name, tempfile: binary_file }
  url = "http://localhost:4567/api/info"
  url = URI.parse(url)
  req = Net::HTTP::Post.new(url.path)
  req.initialize_http_header({
    "CLIENT_ID" => MOCK_CLIENT_ID,
    "REFRESH_TOKEN" => MOCK_REFRESH_TOKEN,
    "ACCESS_TOKEN" => MOCK_ACCESS_TOKEN,
    "REQUEST" => MOCK_REQUEST,
    "ACTION" => "avatar"
  })
  req.set_form(data, "multipart/form-data")
  res = Net::HTTP.new(url.host, url.port).start do |http|
    http.request(req)
  end
ensure
  binary_file.close
end