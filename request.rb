require 'net/http'
require 'uri'
require 'json'

MOCK_GUEST = '{"name":"look","password":"2222222"}'

MOCK_REQUEST = 'edit-password'

MOCK_ACTION = 'avatar'

#edit_password
MOCK_INSTS = {"oldPassword" => "111111111", "newPpassword" => "111111111"}

#edit_profile
#MOCK_INSTS = {"gender" => "male"}

#upload_file
#MOCK_INSTS = {"action" => "avatar", "filename" => "a.jpg", "tempfile" => "xxxxxxx"}

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

MOCK_CLIENT_ID = 'NA==\n'

MOCK_REFRESH_TOKEN = 'eyJhbGciOiJIUzI1NiJ9.eyJndWVzdCI6Im1vY2siLCJ0aW1lIjoiMTUzNTA4NDY2MiJ9.gLjbu04lXXk0oUhVjPcaTyH9gC-GUKMUxZabUD8Euug'

MOCK_ACCESS_TOKEN = 'eyJhbGciOiJIUzI1NiJ9.eyJyZWZyZXNoIjoiMTUzNTA4NTc1MCIsInRpbWUiOiIxNTM1MDg1NzUwIn0.oGCH1i6VGELtPutQYk-8eJz8q0mZiKPS6oA99cr0WYY'

def create_agent
    uri = URI('http://localhost:4567/api/info')
    http = Net::HTTP.new(uri.host, uri.port)
    req = Net::HTTP::Post.new(uri.path, 'Content-Type' => 'application/json')
    req.initialize_http_header({
        "CLIENT_ID" => MOCK_CLIENT_ID,
        "REFRESH_TOKEN" => MOCK_REFRESH_TOKEN,
        "ACCESS_TOKEN" => MOCK_ACCESS_TOKEN,
        "REQUEST" => MOCK_REQUEST,
        "ACTION" => MOCK_ACTION
    })
    req.body = {name: "mocker", password: "111111111", instruction: MOCK_INSTS}.to_json
    res = http.request(req)
    puts "response: #{res.body}"
    puts "http版本：#{res.http_version}"
    puts "响应代码： #{res.code}"
    puts "响应信息：#{res.message}"
    puts "uri：#{res.uri}"
    puts "解码信息：#{res.decode_content}"
    res.header.each do |k,v|
      puts "#{k}:#{v}"
    end
rescue => e
    puts "failed #{e}"
end

create_agent