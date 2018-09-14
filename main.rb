require 'sinatra'
require 'data_mapper'
require 'bcrypt'
require 'json'
require 'jwt'
require 'base64'
require './support'


DataMapper.setup(:default, ENV['DATABASE_URL'] || "sqlite3://#{Dir.pwd}/models/amazeinn.db")

class Guest
  include DataMapper::Resource
  property :_id,              Serial
  property :name,             String, :key => true, :required => true
  property :password,         Text, :required => true
  property :created_on,       DateTime, :required => true
  property :last_login,       DateTime
  property :refresh_token,    Text
  property :access_token,     Text
  property :last_refresh,     DateTime 

  property :nickname,         String
  property :gender,           String, :default  => "Other"
  property :email,            String
  property :country,          String
  property :intro,            Text
  property :avatar,           String
  property :bg_music,         String
  property :bg_image,         String

  property :follow_num,       Integer, :default  => 0
  property :follower_num,     Integer, :default  => 0
  property :message_num,      Integer, :default  => 0
  property :liked_num,        Integer, :default  => 0
  property :like_times,       Integer, :default  => 6
  property :last_like,        DateTime

  property :floor_num,        Integer
  property :room_num,         Integer
  property :game_floor,       Integer
  property :isreal,           Boolean, :default  => false

end

class Message
  include DataMapper::Resource
  property :message_id,       Serial
  property :guest_id,         Integer
  property :content,          Text
  property :send_time,        DateTime, :required => true
  property :liked_count,      Integer, :default  => 0
end

class Room
  include DataMapper::Resource
  property :room_id,          Serial
  property :room_floor,       Integer
  property :room_num,         Integer
  property :isempty,          Boolean, :default  => true
end

class Contact
  include DataMapper::Resource
  property :contact_id,       Serial
  property :initiator,        Integer
  property :acceptor,         Integer
  property :build_time,       DateTime, :required => true
end

def token_generate(pl)
  JWT.encode(pl, Something::SECRET, 'HS256')
end

def token_payload(tk)
  JWT.decode(tk, Something::SECRET, true, { algorithm: 'HS256' })
end

def guest_create(obj)
  @res = Something::RESPONSE
  if Guest.last(:name => obj["username"]).nil?
    @emptyroom = Room.first(:isempty => true)
    if @emptyroom.nil?
      [200] + @res + [{failed: 1}.to_json]
    else
      @password_hash = BCrypt::Password.create(obj["password"])
      @newguest = Guest.new(:name => obj["username"],
        :password => @password_hash,
        :created_on => Time.now,
        :isreal => true)
      @newguest.save
      if @newguest._id <= Something::GUESTS_LIMIT
        @arr = IO.readlines(Something::DIR_RAND)
        @newguest.update(
          :floor_num => Something.calculate_floor(@arr[@newguest._id-1].chomp.to_i),
          :room_num => Something.calculate_room(@arr[@newguest._id-1].chomp.to_i))
        @bookroom = Room.first(
          :room_floor => @newguest.floor_num,
          :room_num => @newguest.room_num)
        @bookroom.update(:isempty => false)
      else
        @newguest.update(
          :room_floor => @emptyroom.floor_num,
          :room_num => @emptyroom.room_num)
        @emptyroom.update(:isempty => false)
      end
      [200] + @res + [{}.to_json]
    end
  else
    [200] + @res + [{failed: 2}.to_json]
  end
end

def guest_login(obj)
  @res = Something::RESPONSE
  @guest = Guest.first(:name => obj["username"])
  if @guest.nil?
    [200] + @res + [{failed: 3}.to_json]
  elsif BCrypt::Password.new(@guest.password) == obj["password"]
    @now = Time.now.to_i.to_s
    @refresh_payload = { guest: obj["username"],
                         time: @now }
    @refresh_token = token_generate(@refresh_payload)
    @access_payload = { refresh: @now,
                        time: @now }
    @access_token = token_generate(@access_payload)
    @guest.update(
      :game_floor => Random.rand(99)+1,
      :refresh_token => @refresh_token,
      :access_token => @access_token,
      :last_login => Time.now,
      :last_refresh => Time.now)
    @mems = Array.new(6)
    for i in 0..5
      @mem = Guest.first(:floor_num => @guest.game_floor, :room_num => i+1)
      if @mem.nil?
        @mems[i] = {
          room: i+1,
          isempty: true
        }
      else
        @mems[i] = {
          room: i+1,
          name: @mem.name,
          isempty: false
        }
      end
    end
    @data = {
      client_id: Base64.encode64(@guest._id.to_s),
      name: @guest.name,
      refresh_token: @guest.refresh_token,
      access_token: @guest.access_token,
      avatar: @guest.avatar
    }
    [200] + @res + [{result: @data}.to_json]
  else
    [200] + @res + [{failed: 4}.to_json]
  end
end

def guest_leave(obj)
  @res = Something::RESPONSE
  @guest = Guest.first(:_id => Base64.decode64(obj["HTTP_CLIENT_ID"]).to_i)
  if @guest.nil?
    [200] + @res + [{failed: 3}.to_json]
  elsif token_compare(@guest, obj["HTTP_ACCESS_TOKEN"])
    @guest.update(:refresh_token => nil,
                  :access_token => nil)
    [200] + @res + [{}.to_json]
  else
    [401] + @res + [{}.to_json]
  end
end

def guest_delete(obj, pswd)
  @res = Something::RESPONSE
  @guest = Guest.first(:_id => Base64.decode64(obj["HTTP_CLIENT_ID"]).to_i)
  if BCrypt::Password.new(@guest.password) != pswd
    [200] + @res + [{failed: 4}.to_json]
  elsif token_compare(@guest, obj["HTTP_ACCESS_TOKEN"])
    @messages = Message.all(:guest_id => @guest._id)
    @room = Room.first(:room_floor => @guest.floor_num,
                       :room_num => @guest.room_num)
    @relations = Contact.all(:initiator => @guest._id) + Contact.all(:acceptor => @guest._id)
    @messages.each do |message|
      message.destroy
    end
    @room.update(:isempty => true)
    @relations.each do |relation|
      relation.destroy
    end
    @guest.destroy
    [200] + @res + [{}.to_json]
  else
    [401] + @res + [{}.to_json]
  end
end

def token_valid(guest)
  Time.now.to_i - Time.parse(guest.last_refresh.to_s).to_i <= Something::EXPIRE_TIME
end

def token_compare(guest, token)
  if token_valid(guest) && guest.access_token == token
    return true
  else
    return false
  end
end

def token_update(obj)
  @res = Something::RESPONSE
  @guest = Guest.first(:_id => Base64.decode64(obj["HTTP_CLIENT_ID"]).to_i)
  if @guest.refresh_token == obj["HTTP_REFRESH_TOKEN"]
    @now = Time.now.to_i.to_s
    @payload_old = token_payload(obj["HTTP_REFRESH_TOKEN"])
    @payload_new = { refresh: @payload_old[0]["time"],
                     time: @now }
    @token_new = token_generate(@payload_new)
    @guest.update(:access_token => @token_new, :last_refresh => Time.now)
    @data = {
      access_token: @guest.access_token
    }
    [200] + @res + [{result: @data}.to_json]
  else
    [401] + @res + [{}.to_json]
  end
end

def case_guest_info(params, req)
  @res = Something::RESPONSE
  case req["HTTP_REQUEST"]
    when "enter-index" then enter_index(params, req)
    when "enter-room" then enter_room(params, req)
    when "edit-password" then edit_password(params, req)
    when "edit-profile" then edit_profile(params, req)
    when "upload-file" then upload_file(params, req)
    when "send-message" then send_message(params, req)
    when "show-message" then show_message(params, req)
    when "use-lift" then use_lift(params, req)
    when "to-floor1" then to_floor1(params, req)
    when "follow-guest" then follow_guest(params, req)
    when "unfollow-guest" then unfollow_guest(params, req)
    when "show-follows" then show_follows(params, req)
    when "show-followers" then show_followers(params, req)
    when "like-message" then like_message(params, req)
    when "dislike-message" then dislike_message(params, req)
    when "popular-messages" then popular_messages(params, req)
    when "popular-guests" then popular_guests(params, req)
    else [400] + @res + [{}.to_json]
  end
end

def enter_index(params, req)
  @res = Something::RESPONSE
  @guest = Guest.first(:_id => Base64.decode64(req["HTTP_CLIENT_ID"]).to_i)
  @mems = Array.new(6)
  for i in 0..5
    @mem = Guest.first(:floor_num => @guest.game_floor, :room_num => i+1)
    if @mem.nil?
      @mems[i] = {
        id: nil,
        name: nil,
        avatar: nil,
        isempty: true
      }
    else
      @mems[i] = {
        id: Base64.encode64(@mem._id.to_s),
        name: @mem.name,
        avatar: @mem.avatar,
        isempty: false
      }
    end
  end
  @data = {
    game_floor: @guest.game_floor,
    members: @mems
  }
  [200] + @res + [{result: @data}.to_json]
end

def enter_room(params, req)
  @res = Something::RESPONSE
  @insts = JSON.parse(params["instruction"])
  @guest = Guest.first(:_id => Base64.decode64(@insts["id"]).to_i)
  @mess = Message.last(:guest_id => @guest._id)
  @recent_message = {}
  if @mess.nil?
    @recent_message = nil
  else
    @recent_message = {
      message_id: @mess.message_id,
      content: @mess.content,
      send_time: @mess.send_time,
      liked_count: @mess.liked_count
    }
  end
  @data = {
    name: @guest.name,
    nickname: @guest.nickname,
    gender: @guest.gender,
    email: @guest.email,
    country: @guest.country,
    intro: @guest.intro,
    avatar: @guest.avatar,
    bg_music: @guest.bg_music,
    bg_image: @guest.bg_image,
    follow_num: @guest.follow_num,
    follower_num: @guest.follower_num,
    message_num: @guest.message_num,
    liked_num: @guest.liked_num,
    message: @recent_message
  }
  [200] + @res + [{result: @data}.to_json]
end

def edit_password(params, req)
  @res = Something::RESPONSE
  @guest = Guest.first(:_id => Base64.decode64(req["HTTP_CLIENT_ID"]).to_i)
  @insts = JSON.parse(params["instruction"])
  if BCrypt::Password.new(@guest.password) == @insts["oldPassword"]
    @password_hash = BCrypt::Password.create(@insts["newPassword"])
    @guest.update(:password => @password_hash)
    [200] + @res + [{}.to_json]
  else
    [200] + @res + [{failed: 4}.to_json]
  end
end

def edit_profile(params, req)
  @res = Something::RESPONSE
  @guest = Guest.first(:_id => Base64.decode64(req["HTTP_CLIENT_ID"]).to_i)
  @action = params["instruction"].to_s
  @case = @action[2,4]
  @insts = JSON.parse(params["instruction"])
  case @case
    when "nick" then @guest.update(:nickname => @insts["nickname"])
    when "gend" then @guest.update(:gender => @insts["gender"])
    when "emai" then @guest.update(:email => @insts["email"])
    when "coun" then @guest.update(:country => @insts["country"])
    when "intr" then @guest.update(:intro => @insts["intro"])
    when "avat" then @guest.update(:avatar => @insts["avatar"])
    when "bg_m" then @guest.update(:bg_music => @insts["bg_music"])
    when "bg_i" then @guest.update(:bg_image => @insts["bg_image"])
  end
  [200] + @res + [{}.to_json]
end

def upload_file(params, req)
  @res = Something::RESPONSE
  case req["HTTP_ACTION"]
    when "avatar" then @dir = Something::DIR_AVATAR
    when "bg_music" then @dir = Something::DIR_BG_MUSIC
    when "bg_image" then @dir = Something::DIR_BG_IMAGE
  end
  @guest = Guest.first(:_id => Base64.decode64(req["HTTP_CLIENT_ID"]).to_i)
  @tempfile = params["file"]["tempfile"]
  @filename = params["file"]["filename"]
  @now = Time.now
  @savename = @guest._id.to_s + '_' + @now.to_i.to_s + '_' + @now.usec.to_s + File.extname(@filename)
  @target = @dir + @savename
  File.new(@target, "w")
  File.open(@target, 'w+') {|f| f.write File.read(@tempfile) }
  @guest.update(req["HTTP_ACTION"] => @target)
  [200] + @res + [{}.to_json]
end

def send_message(params, req)
  @res = Something::RESPONSE
  @guest = Guest.first(:_id => Base64.decode64(req["HTTP_CLIENT_ID"]).to_i)
  @insts = JSON.parse(params["instruction"])
  @new_message = Message.new(
    :guest_id => @guest._id,
    :content => @insts["message"],
    :send_time => Time.now)
  @new_message.save
  @guest.update(:message_num => @guest.message_num + 1)
  @data = {
    message_id:@new_message.message_id,
    content: @new_message.content,
    send_time: DateTime.parse(@new_message.send_time.to_s).strftime('%Y-%m-%d %H:%M:%S').to_s,
    liked_count: @new_message.liked_count
  }
  [200] + @res + [{result: @data}.to_json]
end

def show_message(params, req)
  @res = Something::RESPONSE
  @insts = JSON.parse(params["instruction"])
  @guest = Guest.first(:_id => Base64.decode64(@insts["id"]).to_i)
  @messages = Message.all(:guest_id => @guest._id, :order => [ :message_id.desc ])
  if @guest.message_num == 0
    @data = nil
  else
    @data = Array.new(@guest.message_num)
    @messages.each_with_index do |message, i|
      @data[i] = {
        message_id:message.message_id,
        content: message.content,
        send_time: DateTime.parse(message.send_time.to_s).strftime('%Y-%m-%d %H:%M:%S').to_s,
        liked_count: message.liked_count
      }
    end
  end
  [200] + @res + [{result: @data}.to_json]
end

def use_lift(params, req)
  @guest = Guest.first(:_id => Base64.decode64(req["HTTP_CLIENT_ID"]).to_i)
  @guest.update(:game_floor => Random.rand(99)+1)
  enter_index(params, req)
end

def to_floor1(params, req)
  @guest = Guest.first(:_id => Base64.decode64(req["HTTP_CLIENT_ID"]).to_i)
  @guest.update(:game_floor => 1)
  enter_index(params, req)
end

def follow_guest(params, req)
  @res = Something::RESPONSE
  @insts = JSON.parse(params["instruction"])
  @guest = Guest.first(:_id => Base64.decode64(req["HTTP_CLIENT_ID"]).to_i)
  @room_owner = Guest.first(:_id=> Base64.decode64(@insts["id"]).to_i)
  @new_contact = Contact.new(:initiator => @guest._id,
                             :acceptor => @room_owner._id,
                             :build_time => Time.now)
  @new_contact.save
  @guest.update(:follow_num => @guest.follow_num + 1)
  @room_owner.update(:follower_num => @room_owner.follower_num + 1)
  [200] + @res + [{}.to_json]
end

def unfollow_guest(params, req)
  @res = Something::RESPONSE
  @insts = JSON.parse(params["instruction"])
  @guest = Guest.first(:_id => Base64.decode64(req["HTTP_CLIENT_ID"]).to_i)
  @room_owner = Guest.first(:_id => Base64.decode64(@insts["id"]).to_i)
  @old_contact = Contact.first(:initiator => @guest._id,
                             :acceptor => @room_owner._id)
  @old_contact.destroy
  @guest.update(:follow_num => @guest.follow_num - 1)
  @room_owner.update(:follower_num => @room_owner.follower_num - 1)
  [200] + @res + [{}.to_json]
end

def show_follows(params, req)
  @res = Something::RESPONSE
  @insts = JSON.parse(params["instruction"])
  @guest = Guest.first(:_id => Base64.decode64(@insts["id"]).to_i)
  @follows = Contact.all(:initiator => @guest._id, :order => [ :contact_id.desc ])
  if @guest.follow_num == 0
    @data = nil
  else
    @data = Array.new(@guest.follow_num)
    @follows.each_with_index do |follow, i|
      @follow_guest = Guest.first(:_id => follow.acceptor)
      @data[i] = {
        name: @follow_guest.name,
        gender: @follow_guest.gender,
        avatar: @follow_guest.avatar
      }
    end
  end
  [200] + @res + [{result: @data}.to_json]
end

def show_followers(params, req)
  @res = Something::RESPONSE
  @insts = JSON.parse(params["instruction"])
  @guest = Guest.first(:_id => Base64.decode64(@insts["id"]).to_i)
  @followers = Contact.all(:acceptor => @guest._id, :order => [ :contact_id.desc ])
  if @guest.follower_num == 0
    @data = nil
  else
    @data = Array.new(@guest.follower_num)
    @followers.each_with_index do |follower, i|
      @follower_guest = Guest.first(:_id => follower.initiator)
      @data[i] = {
        name: @follower_guest.name,
        gender: @follower_guest.gender,
        avatar: @follower_guest.avatar
      }
    end
  end
  [200] + @res + [{result: @data}.to_json]
end

def like_message(params, req)
  @res = Something::RESPONSE
  @insts = JSON.parse(params["instruction"])
  @guest = Guest.first(:_id => Base64.decode64(req["HTTP_CLIENT_ID"]).to_i)
  @now = Time.now
  if @guest.last_like.nil? || @now.year != @guest.last_like.year || (@now.yday - @guest.last_like.yday) >=1
    @guest.update(:like_times => 6)
  end
  if @guest.like_times == 0
    [200] + @res + [{failed: 5}.to_json]
  else
    @message = Message.first(:message_id => @insts["message_id"])
    @like_guest = Guest.first(:_id => @message.guest_id)
    @message.update(:liked_count => @message.liked_count + 1)
    @like_guest.update(:liked_num => @like_guest.liked_num + 1)
    @guest.update(:like_times => @guest.like_times - 1,
                  :last_like => Time.now)
    [200] + @res + [{}.to_json]
  end
end

def dislike_message(params, req)
  @res = Something::RESPONSE
  @insts = JSON.parse(params["instruction"])
  @guest = Guest.first(:_id => Base64.decode64(req["HTTP_CLIENT_ID"]).to_i)
  @now = Time.now
  if @guest.last_like.nil? || @now.year != @guest.last_like.year || (@now.yday - @guest.last_like.yday) >=1
    @guest.update(:like_times => 6)
  end
  if @guest.like_times == 0
    [200] + @res + [{failed: 5}.to_json]
  else
    @message = Message.first(:message_id => @insts["message_id"])
    @like_guest = Guest.first(:_id => @message.guest_id)
    @message.update(:liked_count => @message.liked_count - 1)
    @like_guest.update(:liked_num => @like_guest.liked_num - 1)
    @guest.update(:like_times => @guest.like_times - 1,
                  :last_like => Time.now)
    [200] + @res + [{}.to_json]
  end
end

def popular_messages(params, req)
  @res = Something::RESPONSE
  @messages = Message.all(:limit => 6,  :order => [ :liked_count.desc ])
  @num = Message.count(:limit => 6,  :order => [ :liked_count.desc ])
  if @num == 0
    @data = nil
  else
    @data = Array.new(@num)
    @messages.each_with_index do |message, i|
      @data[i] = {
        message_id:message.message_id,
        guest_id: message.guest_id,
        content: message.content,
        send_time: DateTime.parse(message.send_time.to_s).strftime('%Y-%m-%d %H:%M:%S').to_s,
        liked_count: message.liked_count
      }
    end
  end
  [200] + @res + [{result: @data}.to_json]
end

def popular_guests(params, req)
  @res = Something::RESPONSE
  @popular_guests = Guest.all(:limit => 6,  :order => [ :follower_num.desc ])
  @num = Guest.all(:limit => 6,  :order => [ :follower_num.desc ])
  if @num == 0
    @data = nil
  else
    @data = Array.new(@num)
    @popular_guests.each_with_index do |guest, i|
      @data[i] = {
        name: guest.name,
        gender: guest.gender,
        avatar: guest.avatar,
        follower_num: guest.follower_num
      }
    end
  end
  [200] + @res + [{result: @data}.to_json]
end

DataMapper.finalize


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
