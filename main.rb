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
  if Guest.last(:name => obj["name"]).nil?
    @emptyroom = Room.first(:isempty => true)
    if @emptyroom.nil?
      Something.message_checkin_full
    else
      @password_hash = BCrypt::Password.create(obj["password"])
      @newguest = Guest.new(:name => obj["name"],
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
      Something.message_checkin_success
    end
  else
    Something.message_checkin_exist(obj["name"])
  end
end

def guest_login(obj)
  @guest = Guest.first(:name => obj["name"])
  if @guest.nil?
    Something.message_login_not_exist(obj["name"])
  elsif BCrypt::Password.new(@guest.password) == obj["password"]
    @now = Time.now.to_i.to_s
    @refresh_payload = { guest: obj["name"],
                         time: @now }
    @refresh_token = token_generate(@refresh_payload)
    @access_payload = { refresh: @now,
                        time: @now }
    @access_token = token_generate(@access_payload)
    @guest.update(
      :game_floor => Random.rand(99)+1,
      :refresh_token => @refresh_token,
      :access_token => @access_token,
      :last_login => Time.now)
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
    @res = {
      client_id: Base64.encode64(@guest._id.to_s),
      refresh_token: @guest.refresh_token,
      access_token: @guest.access_token,
      expires_in: 86399,
      avatar: @guest.avatar,
      game_floor: @guest.game_floor,
      members: @mems
    }
    Something.message_login_success(@res)
  else
    Something.message_wrong_password
  end
end

def token_compare(obj)
  @guest = Guest.first(:_id => Base64.decode64(obj["HTTP_CLIENT_ID"]).to_i)
  if @guest.access_token == obj["HTTP_ACCESS_TOKEN"]
    return false
  else
    Something.message_token_fail
  end
end

def token_update(obj)
  @guest = Guest.first(:_id => Base64.decode64(obj["HTTP_CLIENT_ID"]).to_i)
  if @guest.refresh_token == obj["HTTP_REFRESH_TOKEN"]
    @now = Time.now.to_i.to_s
    @payload_old = token_payload(obj["HTTP_REFRESH_TOKEN"])
    @payload_new = { refresh: @payload_old[0]["time"],
                     time: @now }
    @token_new = token_generate(@payload_new)
    @guest.update(:access_token => @token_new)
    @res = {
      name: @guest.name,
      access_token: @guest.access_token,
      expires_in: 86399
    }
    Something.message_token_update_success(@res)
  else
    Something.message_token_fail
  end
end

def guest_leave(obj)
  @guest = Guest.first(:_id => Base64.decode64(obj["HTTP_CLIENT_ID"]).to_i)
  if @guest.nil?
    Something.message_login_not_exist
  elsif @guest.access_token == obj["HTTP_ACCESS_TOKEN"]
    @guest.update(:refresh_token => nil,
                  :access_token => nil)
    Something.message_leave_success
  else
    Something.message_token_fail
  end
end

def guest_delete(obj, pswd)
  @guest = Guest.first(:_id => Base64.decode64(obj["HTTP_CLIENT_ID"]).to_i)
  if BCrypt::Password.new(@guest.password) != pswd
    Something.message_wrong_password
  elsif @guest.access_token != obj["HTTP_ACCESS_TOKEN"]
    Something.message_token_fail
  else
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
    Something.message_checkout_success
  end
end

def case_guest_info(params, req)
  case req["HTTP_REQUEST"]
    when "enter-index" then enter_index(params, req)
    when "enter-room" then enter_room(params, req)
    when "edit-password" then edit_password(params, req)
    when "edit-profile" then edit_profile(params, req)
    when "send-message" then send_message(params, req)
    when "show-message" then show_message(params, req)
    when "use-lift" then use_lift(params, req)
    when "to-floor1" then to_floor1(params, req)
    when "knock-door" then knock_door(params, req)
    when "follow-guest" then follow_guest(params, req)
    when "unfollow-guest" then unfollow_guest(params, req)
    when "show-follows" then show_follows(params, req)
    when "show-followers" then show_followers(params, req)
    when "like-message" then like_message(params, req)
    when "dislike-message" then dislike_message(params, req)
    when "popular-messages" then popular_messages(params, req)
    when "popular-guests" then popular_guests(params, req)
    else Something.message_request_fail
  end
end

def enter_index(params, req)
  @guest = Guest.first(:_id => Base64.decode64(req["HTTP_CLIENT_ID"]).to_i)
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
  @res = {
    name: @guest.name,
    created_on: DateTime.parse(@guest.created_on.to_s).strftime('%Y-%m-%d %H:%M:%S').to_s,
    last_login: DateTime.parse(@guest.last_login.to_s).strftime('%Y-%m-%d %H:%M:%S').to_s,
    avatar: @guest.avatar,
    game_floor: @guest.game_floor,
    members: @mems
  }
  Something.message_enter_index(@res)
end

def enter_room(params, req)
  @guest = Guest.first(:_id => Base64.decode64(req["HTTP_CLIENT_ID"]).to_i)
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
  @res = {
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
  Something.message_enter_room(@res)
end

def edit_password(params, req)
  @guest = Guest.first(:_id => Base64.decode64(req["HTTP_CLIENT_ID"]).to_i)
  if BCrypt::Password.new(@guest.password) == params["instruction"]["old_password"]
    @password_hash = BCrypt::Password.create(params["instruction"]["new_password"])
    @guest.update(:password => @password_hash)
    Something.message_edit_password_success
  else
    Something.message_edit_password_fail
  end
end

def edit_profile(params, req)
  @guest = Guest.first(:_id => Base64.decode64(req["HTTP_CLIENT_ID"]).to_i)
  @inst = params["instruction"].to_s
  @case = @inst[2,4]
  case @case
    when "nick" then @guest.update(:nickname => params["instruction"]["nickname"])
    when "gend" then @guest.update(:gender => params["instruction"]["gender"])
    when "emai" then @guest.update(:email => params["instruction"]["email"])
    when "coun" then @guest.update(:country => params["instruction"]["country"])
    when "intr" then @guest.update(:intro => params["instruction"]["intro"])
    when "avat" then @guest.update(:avatar => params["instruction"]["avatar"])
    when "bg_m" then @guest.update(:bg_music => params["instruction"]["bg_music"])
    when "bg_i" then @guest.update(:bg_image => params["instruction"]["bg_image"])
  end
  Something.message_edit_profile_success
end

def send_message(params, req)
  @guest = Guest.first(:_id => Base64.decode64(req["HTTP_CLIENT_ID"]).to_i)
  @new_message = Message.new(
    :guest_id => @guest._id,
    :content => params["instruction"]["message"],
    :send_time => Time.now)
  @new_message.save
  @guest.update(:message_num => @guest.message_num + 1)
  @res = {
    message_id:@new_message.message_id,
    content: @new_message.content,
    send_time: DateTime.parse(@new_message.send_time.to_s).strftime('%Y-%m-%d %H:%M:%S').to_s,
    liked_count: @new_message.liked_count
  }
  Something.message_send_message(@res)
end

def show_message(params, req)
  @guest = Guest.first(:_id => Base64.decode64(req["HTTP_CLIENT_ID"]).to_i)
  @messages = Message.all(:guest_id => @guest._id, :order => [ :message_id.desc ])
  if @guest.message_num == 0
    @res = nil
  else
    @res = Array.new(@guest.message_num)
    @messages.each_with_index do |message, i|
      @res[i] = {
        message_id:message.message_id,
        content: message.content,
        send_time: DateTime.parse(message.send_time.to_s).strftime('%Y-%m-%d %H:%M:%S').to_s,
        liked_count: message.liked_count
      }
    end
  end
  Something.message_show_message(@res)
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

def knock_door(params, req)
  @guest = Guest.first(:_id => Base64.decode64(req["HTTP_CLIENT_ID"]).to_i)
  @room_owner = Guest.first(:name => params["instruction"]["name"])
  @mess = Message.last(:guest_id => @room_owner._id)
  @recent_message = {}
  if @mess.nil?
    @recent_message = nil
  else
    @recent_message = {
      message_id:@mess.message_id,
      content: @mess.content,
      send_time: @mess.send_time,
      liked_count: @mess.liked_count
    }
  end
  @res = {
    name: @room_owner.name,
    nickname: @room_owner.nickname,
    gender: @room_owner.gender,
    email: @room_owner.email,
    country: @room_owner.country,
    intro: @room_owner.intro,
    avatar: @room_owner.avatar,
    bg_music: @room_owner.bg_music,
    bg_image: @room_owner.bg_image,
    follow_num: @room_owner.follow_num,
    follower_num: @room_owner.follower_num,
    message_num: @room_owner.message_num,
    liked_num: @room_owner.liked_num,
    message: @recent_message
  }
  Something.message_knock_door(@res)
end

def follow_guest(params, req)
  @guest = Guest.first(:_id => Base64.decode64(req["HTTP_CLIENT_ID"]).to_i)
  @room_owner = Guest.first(:name => params["instruction"]["name"])
  @new_contact = Contact.new(:initiator => @guest._id,
                             :acceptor => @room_owner._id,
                             :build_time => Time.now)
  @new_contact.save
  @guest.update(:follow_num => @guest.follow_num + 1)
  @room_owner.update(:follower_num => @room_owner.follower_num + 1)
  Something.message_follow_guest
end

def unfollow_guest(params, req)
  @guest = Guest.first(:_id => Base64.decode64(req["HTTP_CLIENT_ID"]).to_i)
  @room_owner = Guest.first(:name => params["instruction"]["name"])
  @old_contact = Contact.first(:initiator => @guest._id,
                             :acceptor => @room_owner._id)
  @old_contact.destroy
  @guest.update(:follow_num => @guest.follow_num - 1)
  @room_owner.update(:follower_num => @room_owner.follower_num - 1)
  Something.message_unfollow_guest
end

def show_follows(params, req)
  @guest = Guest.first(:_id => Base64.decode64(req["HTTP_CLIENT_ID"]).to_i)
  @follows = Contact.all(:initiator => @guest._id, :order => [ :contact_id.desc ])
  if @guest.follow_num == 0
    @res = nil
  else
    @res = Array.new(@guest.follow_num)
    @follows.each_with_index do |follow, i|
      @follow_guest = Guest.first(:_id => follow.acceptor)
      @res[i] = {
        name: @follow_guest.name,
        gender: @follow_guest.gender,
        avatar: @follow_guest.avatar
      }
    end
  end
  Something.message_show_follows(@res)
end

def show_followers(params, req)
  @guest = Guest.first(:_id => Base64.decode64(req["HTTP_CLIENT_ID"]).to_i)
  @followers = Contact.all(:acceptor => @guest._id, :order => [ :contact_id.desc ])
  if @guest.follower_num == 0
    @res = nil
  else
    @res = Array.new(@guest.follower_num)
    @followers.each_with_index do |follower, i|
      @follower_guest = Guest.first(:_id => follower.initiator)
      @res[i] = {
        name: @follower_guest.name,
        gender: @follower_guest.gender,
        avatar: @follower_guest.avatar
      }
    end
  end
  Something.message_show_followers(@res)
end

def like_message(params, req)
  @guest = Guest.first(:_id => Base64.decode64(req["HTTP_CLIENT_ID"]).to_i)
  @now = Time.now
  if @guest.last_like.nil? || @now.year != @guest.last_like.year || (@now.yday - @guest.last_like.yday) >=1
    @guest.update(:like_times => 6)
  end
  if @guest.like_times == 0
    Something.message_no_like_time
  else
    @message = Message.first(:message_id => params["instruction"]["message_id"])
    @like_guest = Guest.first(:_id => @message.guest_id)
    @message.update(:liked_count => @message.liked_count + 1)
    @like_guest.update(:liked_num => @like_guest.liked_num + 1)
    @guest.update(:like_times => @guest.like_times - 1,
                  :last_like => Time.now)
    Something.message_like_message_success
  end
end

def dislike_message(params, req)
  @guest = Guest.first(:_id => Base64.decode64(req["HTTP_CLIENT_ID"]).to_i)
  @now = Time.now
  if @guest.last_like.nil? || @now.year != @guest.last_like.year || (@now.yday - @guest.last_like.yday) >=1
    @guest.update(:like_times => 6)
  end
  if @guest.like_times == 0
    Something.message_no_like_time
  else
    @message = Message.first(:message_id => params["instruction"]["message_id"])
    @like_guest = Guest.first(:_id => @message.guest_id)
    @message.update(:liked_count => @message.liked_count - 1)
    @like_guest.update(:liked_num => @like_guest.liked_num - 1)
    @guest.update(:like_times => @guest.like_times - 1,
                  :last_like => Time.now)
    Something.message_dislike_message_success
  end
end

def popular_messages(params, req)
  @guest = Guest.first(:_id => Base64.decode64(req["HTTP_CLIENT_ID"]).to_i)
  @messages = Message.all(:limit => 6,  :order => [ :liked_count.desc ])
  @num = Message.count(:limit => 6,  :order => [ :liked_count.desc ])
  if @num == 0
    @res = nil
  else
    @res = Array.new(@num)
    @messages.each_with_index do |message, i|
      @res[i] = {
        message_id:message.message_id,
        guest_id: message.guest_id,
        content: message.content,
        send_time: DateTime.parse(message.send_time.to_s).strftime('%Y-%m-%d %H:%M:%S').to_s,
        liked_count: message.liked_count
      }
    end
  end
  Something.message_popular_messages(@res)
end

def popular_guests(params, req)
  @guest = Guest.first(:_id => Base64.decode64(req["HTTP_CLIENT_ID"]).to_i)
  @popular_guests = Guest.all(:limit => 6,  :order => [ :follower_num.desc ])
  @num = Guest.all(:limit => 6,  :order => [ :follower_num.desc ])
  if @num == 0
    @res = nil
  else
    @res = Array.new(@num)
    @popular_guests.each_with_index do |guest, i|
      @res[i] = {
        name: guest.name,
        gender: guest.gender,
        avatar: guest.avatar,
        follower_num: guest.follower_num
      }
    end
  end
  Something.message_popular_guests(@res)
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

post '/api/checkin' do
  @params = JSON.parse(request.body.read)
  guest_create(@params)
end

post '/api/enter' do
  @params = JSON.parse(request.body.read)
  guest_login(@params)
end

post '/api/leave' do
  @req = JSON.parse(request.env.to_json)
  guest_leave(@req)
end

post '/api/checkout' do
  @params = JSON.parse(request.body.read)
  @req = JSON.parse(request.env.to_json)
  guest_delete(@req, @params["password"])
end

post '/api/info' do
  @params = JSON.parse(request.body.read)
  @req = JSON.parse(request.env.to_json)
  if @res = token_compare(@req)
    @res
  else
    case_guest_info(@params, @req)
  end
end

post '/api/refresh' do
  @req = JSON.parse(request.env.to_json)
  token_update(@req)
end

post '/api/upload' do
  @req = JSON.parse(request.env.to_json)
  if @res = token_compare(@req)
    @res
  else
    case @req["HTTP_ACTION"]
      when "avatar" then @dir = Something::DIR_AVATAR
      when "bg_music" then @dir = Something::DIR_BG_MUSIC
      when "bg_image" then @dir = Something::DIR_BG_IMAGE
    end
    @guest = Guest.first(:_id => Base64.decode64(@req["HTTP_CLIENT_ID"]).to_i)
    @tempfile = params["file"]["tempfile"]
    @filename = params["file"]["filename"]
    @now = Time.now
    @savename = @guest._id.to_s + '_' + @now.to_i.to_s + '_' + @now.usec.to_s + File.extname(@filename)
    @target = @dir + @savename
    File.new(@target, "w")
    File.open(@target, 'w+') {|f| f.write File.read(@tempfile) }
    @guest.update(@req["action"] => @target)
    Something.message_upload_file_success
  end
end