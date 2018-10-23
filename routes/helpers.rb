require 'bcrypt'
require 'json'
require 'jwt'
require 'base64'
require_relative 'constants'

def init_random(num)
  Constants.init_rand(num)
end

def init_room(num)
  0.upto(num-1) { |i|
    _init = Room.new(:room_floor => Constants.calculate_floor(i), :room_num => Constants.calculate_room(i))
    _init.save
    puts "floor#{Constants.calculate_floor(i).to_s}  room#{Constants.calculate_room(i).to_s}  OK!"
  }
  'Complete!'
end

def init_mock(num)
  0.upto(num-1) { |i|
    _name = Constants.new_str(6)
    _obj = {"username" => _name, "password" => "111111111"}
    _res = guest_create(_obj)
    _guest = Guest.last(:name => _name)
    _genders = ['Male', 'Female', 'Other']
    _guest.update(:isreal => false, :gender => _genders[Random.rand(3)-1])
    puts "mock#{(i+1).to_s}: #{_name}  Created!"
  }
  'Complete!'
end

def token_generate(pl)
  JWT.encode(pl, Constants::SECRET, 'HS256')
end

def token_payload(tk)
  JWT.decode(tk, Constants::SECRET, true, { algorithm: 'HS256' })
end

def base_url()
  if ENV['DATABASE_URL'].nil?
    return Constants::DEV_URL
  else
    return Constants::PROD_URL
  end
end

def guest_create(obj)
  _res = Constants::RESPONSE
  if Guest.last(:name => obj["username"]).nil?
    _emptyroom = Room.first(:isempty => true)
    if _emptyroom.nil?
      [200] + _res + [{failed: 1}.to_json]
    else
      _password_hash = BCrypt::Password.create(obj["password"])
      _newguest = Guest.new(:name => obj["username"],
        :password => _password_hash,
        :created_on => Time.now,
        :isreal => true)
      _newguest.save
      if _newguest._id <= Constants::GUESTS_LIMIT
        _arr = IO.readlines(Constants::DIR_RAND)
        _newguest.update(
          :floor_num => Constants.calculate_floor(_arr[_newguest._id-1].chomp.to_i),
          :room_num => Constants.calculate_room(_arr[_newguest._id-1].chomp.to_i))
        _bookroom = Room.first(
          :room_floor => _newguest.floor_num,
          :room_num => _newguest.room_num)
        _bookroom.update(:isempty => false)
      else
        _newguest.update(
          :room_floor => _emptyroom.floor_num,
          :room_num => _emptyroom.room_num)
        _emptyroom.update(:isempty => false)
      end
      [200] + _res + [{}.to_json]
    end
  else
    [200] + _res + [{failed: 2}.to_json]
  end
end

def guest_login(obj)
  _res = Constants::RESPONSE
  _guest = Guest.first(:name => obj["username"])
  if _guest.nil?
    [200] + _res + [{failed: 3}.to_json]
  elsif BCrypt::Password.new(_guest.password) == obj["password"]
    _now = Time.now.to_i.to_s
    _refresh_payload = { guest: obj["username"],
                         time: _now }
    _refresh_token = token_generate(_refresh_payload)
    _access_payload = { refresh: _now,
                        time: _now }
    _access_token = token_generate(_access_payload)
    _guest.update(
      :refresh_token => _refresh_token,
      :access_token => _access_token,
      :last_login => Time.now,
      :last_refresh => Time.now)
    _data = {
      client_id: Base64.encode64(_guest._id.to_s),
      name: _guest.name,
      refresh_token: _guest.refresh_token,
      access_token: _guest.access_token,
      gender: _guest.gender,
      avatar: _guest.avatar
    }
    [200] + _res + [{result: _data}.to_json]
  else
    [200] + _res + [{failed: 4}.to_json]
  end
end

def guest_leave(obj)
  _res = Constants::RESPONSE
  _guest = Guest.first(:_id => Base64.decode64(obj["HTTP_CLIENT_ID"]).to_i)
  if _guest.nil?
    [200] + _res + [{failed: 3}.to_json]
  elsif token_compare(_guest, obj["HTTP_ACCESS_TOKEN"])
    _guest.update(:refresh_token => nil,
                  :access_token => nil)
    [200] + _res + [{}.to_json]
  else
    [401] + _res + [{}.to_json]
  end
end

def guest_delete(obj, pswd)
  _res = Constants::RESPONSE
  _guest = Guest.first(:_id => Base64.decode64(obj["HTTP_CLIENT_ID"]).to_i)
  if BCrypt::Password.new(_guest.password) != pswd
    [200] + _res + [{failed: 4}.to_json]
  elsif token_compare(_guest, obj["HTTP_ACCESS_TOKEN"])
    _messages = Message.all(:guest_id => _guest._id)
    _room = Room.first(:room_floor => _guest.floor_num,
                       :room_num => _guest.room_num)
    _relations = Contact.all(:initiator => _guest._id) + Contact.all(:acceptor => _guest._id)
    _messages.each do |message|
      message.destroy
    end
    _room.update(:isempty => true)
    _relations.each do |relation|
      relation.destroy
    end
    _guest.destroy
    [200] + _res + [{}.to_json]
  else
    [401] + _res + [{}.to_json]
  end
end

def token_valid(guest)
  Time.now.to_i - Time.parse(guest.last_refresh.to_s).to_i <= Constants::EXPIRE_TIME
end

def token_compare(guest, token)
  if token_valid(guest) && guest.access_token == token
    return true
  else
    return false
  end
end

def token_update(obj)
  _res = Constants::RESPONSE
  _guest = Guest.first(:_id => Base64.decode64(obj["HTTP_CLIENT_ID"]).to_i)
  if _guest.refresh_token == obj["HTTP_REFRESH_TOKEN"]
    _now = Time.now.to_i.to_s
    _payload_old = token_payload(obj["HTTP_REFRESH_TOKEN"])
    _payload_new = { refresh: _payload_old[0]["time"],
                     time: _now }
    _token_new = token_generate(_payload_new)
    _guest.update(:access_token => _token_new, :last_refresh => Time.now)
    _data = {
      access_token: _guest.access_token
    }
    [200] + _res + [{result: _data}.to_json]
  else
    [401] + _res + [{}.to_json]
  end
end

def case_guest_info(params, req)
  _res = Constants::RESPONSE
  case req["HTTP_REQUEST"]
  when "enter-index" then enter_index(params, req)
  when "enter-room" then enter_room(params, req)
  when "knock-door" then knock_door(params, req)
  when "edit-password" then edit_password(params, req)
  when "edit-profile" then edit_profile(params, req)
  when "upload-file" then upload_file(params, req)
  when "use-lift" then use_lift(params, req)
  when "to-floor1" then to_floor1(params, req)
  when "follow-guest" then follow_guest(params, req)
  when "unfollow-guest" then unfollow_guest(params, req)
  when "show-follows" then show_follows(params, req)
  when "show-followers" then show_followers(params, req)
  when "send-message" then send_message(params, req)
  when "show-messages" then show_messages(params, req)
  when "like-message" then like_message(params, req)
  when "dislike-message" then dislike_message(params, req)
  when "show-thumbups" then show_thumbups(params, req)
  when "show-thumbdowns" then show_thumbdowns(params, req)
  when "popular-messages" then popular_messages(params, req)
  when "popular-guests" then popular_guests(params, req)
  else [400] + _res + [{}.to_json]
  end
end

def enter_index(params, req)
  _res = Constants::RESPONSE
  _guest = Guest.first(:_id => Base64.decode64(req["HTTP_CLIENT_ID"]).to_i)
  _mems = Array.new(6)
  for i in 0..5
    _mem = Guest.first(:floor_num => _guest.game_floor, :room_num => i+1)
    if _mem.nil?
      _mems[i] = {
        id: nil,
        name: nil,
        gender: nil,
        avatar: nil,
        isempty: true
      }
    else
      _mems[i] = {
        id: Base64.encode64(_mem._id.to_s),
        name: _mem.name,
        gender: _mem.gender,
        avatar: _mem.avatar,
        isempty: false
      }
    end
  end
  _data = {
    game_floor: _guest.game_floor,
    members: _mems
  }
  [200] + _res + [{result: _data}.to_json]
end

def enter_room(params, req)
  _res = Constants::RESPONSE
  _guest = Guest.first(:_id => Base64.decode64(req["HTTP_CLIENT_ID"]).to_i)
  _mess = Message.last(:guest_id => _guest._id)
  _recent_message = {}
  if _mess.nil?
    _recent_message = nil
  else
    _recent_message = {
      message_id: _mess.message_id,
      content: _mess.content,
      send_time: DateTime.parse(_mess.send_time.to_s).to_time.to_i,
      liked_count: _mess.liked_count
    }
  end
  _data = {
    name: _guest.name,
    created_on: DateTime.parse(_guest.created_on.to_s).to_time.to_i,
    last_login: DateTime.parse(_guest.last_login.to_s).to_time.to_i,
    nickname: _guest.nickname,
    gender: _guest.gender,
    email: _guest.email,
    country: _guest.country,
    intro: _guest.intro,
    avatar: _guest.avatar,
    bg_music: _guest.bg_music,
    bg_image: _guest.bg_image,
    follow_num: _guest.follow_num,
    follower_num: _guest.follower_num,
    message_num: _guest.message_num,
    liked_num: _guest.liked_num,
    like_times: _guest.like_times,
    message: _recent_message,
    follows_label: false,
    followed_label: false
  }
  [200] + _res + [{result: _data}.to_json]
end

def knock_door(params, req)
  _res = Constants::RESPONSE
  _ego = Guest.first(:_id => Base64.decode64(req["HTTP_CLIENT_ID"]).to_i)
  _insts = JSON.parse(params["instruction"])
  _guest = Guest.first(:_id => Base64.decode64(_insts["id"]).to_i)
  _mess = Message.last(:guest_id => _guest._id)
  _recent_message = {}
  if _mess.nil?
    _recent_message = nil
  else
    _thumb = Thumb.last(:guest_id => Base64.decode64(req["HTTP_CLIENT_ID"]).to_i, :message_id => _mess.message_id)
    if _thumb.nil?
      _label = nil
    elsif _thumb.isthumbup
      _label = 0
    else
      _label = 1
    end
    _recent_message = {
      message_id: _mess.message_id,
      content: _mess.content,
      send_time: DateTime.parse(_mess.send_time.to_s).to_time.to_i,
      liked_count: _mess.liked_count,
      label: _label
    }
  end
  _follows_contact = Contact.last(:initiator => _ego._id, :acceptor => _guest._id)
  if _follows_contact.nil?
    _follows_label = false
  else
    _follows_label = true
  end
  _followed_contact = Contact.last(:initiator => _guest._id, :acceptor => _ego._id)
  if _followed_contact.nil?
    _followed_label = false
  else
    _followed_label = true
  end
  _data = {
    name: _guest.name,
    created_on: DateTime.parse(_guest.created_on.to_s).to_time.to_i,
    last_login: _guest.last_login ? DateTime.parse(_guest.last_login.to_s).to_time.to_i : nil,
    nickname: _guest.nickname,
    gender: _guest.gender,
    email: _guest.email,
    country: _guest.country,
    intro: _guest.intro,
    avatar: _guest.avatar,
    bg_music: _guest.bg_music,
    bg_image: _guest.bg_image,
    follow_num: _guest.follow_num,
    follower_num: _guest.follower_num,
    message_num: _guest.message_num,
    liked_num: _guest.liked_num,
    like_times: _guest.like_times,
    message: _recent_message,
    follows_label: _follows_label,
    followed_label: _followed_label
  }
  [200] + _res + [{result: _data}.to_json]
end

def edit_password(params, req)
  _res = Constants::RESPONSE
  _guest = Guest.first(:_id => Base64.decode64(req["HTTP_CLIENT_ID"]).to_i)
  _insts = JSON.parse(params["instruction"])
  if BCrypt::Password.new(_guest.password) == _insts["oldPassword"]
    _password_hash = BCrypt::Password.create(_insts["newPassword"])
    _guest.update(:password => _password_hash)
    [200] + _res + [{}.to_json]
  else
    [200] + _res + [{failed: 4}.to_json]
  end
end

def edit_profile(params, req)
  _res = Constants::RESPONSE
  _guest = Guest.first(:_id => Base64.decode64(req["HTTP_CLIENT_ID"]).to_i)
  _action = params["instruction"].to_s
  _case = _action[2,4]
  _insts = JSON.parse(params["instruction"])
  case _case
  when "nick" then _guest.update(:nickname => _insts["nickname"])
  when "gend" then _guest.update(:gender => _insts["gender"])
  when "emai" then _guest.update(:email => _insts["email"])
  when "coun" then _guest.update(:country => _insts["country"])
  when "intr" then _guest.update(:intro => _insts["intro"])
  when "avat" then _guest.update(:avatar => _insts["avatar"])
  when "bg_m" then _guest.update(:bg_music => _insts["bg_music"])
  when "bg_i" then _guest.update(:bg_image => _insts["bg_image"])
  else [400] + _res + [{}.to_json]
  end
  [200] + _res + [{}.to_json]
end

def upload_file(params, req)
  _res = Constants::RESPONSE
  _guest = Guest.first(:_id => Base64.decode64(req["HTTP_CLIENT_ID"]).to_i)
  _tempfile = params["file"]["tempfile"]
  _filename = params["file"]["filename"]
  _now = Time.now
  _savename = _guest._id.to_s + '_' + _now.to_i.to_s + '_' + _now.usec.to_s + File.extname(_filename)
  case req["HTTP_ACTION"]
  when "avatar" then _dir = File.join File.dirname(__FILE__), '..', 'static', 'images', 'avatar'
  when "bg_music" then _dir = File.join File.dirname(__FILE__), '..', 'static', 'music', 'bg_music'
  when "bg_image" then _dir = File.join File.dirname(__FILE__), '..', 'static', 'images', 'bg_image'
  end
  _target = File.join(_dir, _savename)
  FileUtils.mkdir_p(_dir) unless File.exist?(_dir)
  File.open(_target, 'w+') {|f| f.write File.read(_tempfile) }
  case req["HTTP_ACTION"]
  when "avatar" then _url = base_url() + Constants::AVATAR_URL + _savename
  when "bg_music" then _url = base_url() + Constants::BG_MUSIC_URL + _savename
  when "bg_image" then _url = base_url() + Constants::BG_IMAGE_URL + _savename
  end
  _guest.update(req["HTTP_ACTION"] => _url)
  [200] + _res + [{}.to_json]
end

def use_lift(params, req)
  _guest = Guest.first(:_id => Base64.decode64(req["HTTP_CLIENT_ID"]).to_i)
  _guest.update(:game_floor => Random.rand(99)+1)
  enter_index(params, req)
end

def to_floor1(params, req)
  _guest = Guest.first(:_id => Base64.decode64(req["HTTP_CLIENT_ID"]).to_i)
  _guest.update(:game_floor => 1)
  enter_index(params, req)
end

def follow_guest(params, req)
  _res = Constants::RESPONSE
  _insts = JSON.parse(params["instruction"])
  _guest = Guest.first(:_id => Base64.decode64(req["HTTP_CLIENT_ID"]).to_i)
  _room_owner = Guest.first(:_id=> Base64.decode64(_insts["id"]).to_i)
  _new_contact = Contact.new(:initiator => _guest._id,
                             :acceptor => _room_owner._id,
                             :build_time => Time.now)
  _new_contact.save
  _guest.update(:follow_num => _guest.follow_num + 1)
  _room_owner.update(:follower_num => _room_owner.follower_num + 1)
  [200] + _res + [{}.to_json]
end

def unfollow_guest(params, req)
  _res = Constants::RESPONSE
  _insts = JSON.parse(params["instruction"])
  _guest = Guest.first(:_id => Base64.decode64(req["HTTP_CLIENT_ID"]).to_i)
  _room_owner = Guest.first(:_id => Base64.decode64(_insts["id"]).to_i)
  _old_contact = Contact.first(:initiator => _guest._id,
                             :acceptor => _room_owner._id)
  _old_contact.destroy
  _guest.update(:follow_num => _guest.follow_num - 1)
  _room_owner.update(:follower_num => _room_owner.follower_num - 1)
  [200] + _res + [{}.to_json]
end

def show_follows(params, req)
  _res = Constants::RESPONSE
  _guest = Guest.first(:_id => Base64.decode64(req["HTTP_CLIENT_ID"]).to_i)
  _follows = Contact.all(:initiator => _guest._id, :order => [ :contact_id.desc ])
  if _guest.follow_num == 0
    _data = []
  else
    _data = Array.new(_guest.follow_num)
    _follows.each_with_index do |follow, i|
      _follow_guest = Guest.first(:_id => follow.acceptor)
      _data[i] = {
        id: Base64.encode64(_follow_guest._id.to_s),
        name: _follow_guest.name,
        gender: _follow_guest.gender,
        avatar: _follow_guest.avatar,
        follow_time: DateTime.parse(follow.build_time.to_s).to_time.to_i
      }
    end
  end
  [200] + _res + [{result: _data}.to_json]
end

def show_followers(params, req)
  _res = Constants::RESPONSE
  _guest = Guest.first(:_id => Base64.decode64(req["HTTP_CLIENT_ID"]).to_i)
  _followers = Contact.all(:acceptor => _guest._id, :order => [ :contact_id.desc ])
  if _guest.follower_num == 0
    _data = []
  else
    _data = Array.new(_guest.follower_num)
    _followers.each_with_index do |follower, i|
      _follower_guest = Guest.first(:_id => follower.initiator)
      _data[i] = {
        id: Base64.encode64(_follower_guest._id.to_s),
        name: _follower_guest.name,
        gender: _follower_guest.gender,
        avatar: _follower_guest.avatar,
        follow_time: DateTime.parse(follower.build_time.to_s).to_time.to_i
      }
    end
  end
  [200] + _res + [{result: _data}.to_json]
end

def send_message(params, req)
  _res = Constants::RESPONSE
  _guest = Guest.first(:_id => Base64.decode64(req["HTTP_CLIENT_ID"]).to_i)
  _insts = JSON.parse(params["instruction"])
  _new_message = Message.new(
    :guest_id => _guest._id,
    :content => _insts["message"],
    :send_time => Time.now)
  _new_message.save
  _guest.update(:message_num => _guest.message_num + 1)
  [200] + _res + [{}.to_json]
end

def show_messages(params, req)
  _res = Constants::RESPONSE
  _guest = Guest.first(:_id => Base64.decode64(req["HTTP_CLIENT_ID"]).to_i)
  _messages = Message.all(:guest_id => _guest._id, :order => [ :message_id.desc ])
  if _guest.message_num == 0
    _data = []
  else
    _data = Array.new(_guest.message_num)
    _messages.each_with_index do |message, i|
      _data[i] = {
        message_id:message.message_id,
        content: message.content,
        send_time: DateTime.parse(message.send_time.to_s).to_time.to_i,
        liked_count: message.liked_count
      }
    end
  end
  [200] + _res + [{result: _data}.to_json]
end

def like_message(params, req)
  _res = Constants::RESPONSE
  _insts = JSON.parse(params["instruction"])
  _guest = Guest.first(:_id => Base64.decode64(req["HTTP_CLIENT_ID"]).to_i)
  _now = Time.now
  if _guest.last_like.nil? || _now.year != _guest.last_like.year || (_now.yday - _guest.last_like.yday) >=1
    _guest.update(:like_times => 6)
  end
  if _guest.like_times == 0
    [200] + _res + [{failed: 5}.to_json]
  else
    _message = Message.first(:message_id => _insts["message_id"])
    _like_guest = Guest.first(:_id => _message.guest_id)
    _message.update(:liked_count => _message.liked_count + 1)
    _like_guest.update(:liked_num => _like_guest.liked_num + 1)
    _guest.update(:like_times => _guest.like_times - 1,
                  :last_like => Time.now)
    _new_thumb = Thumb.new(:guest_id => _guest._id,
                           :message_id => _message.message_id,
                           :thumb_time => Time.now)
    _new_thumb.save
    [200] + _res + [{}.to_json]
  end
end

def dislike_message(params, req)
  _res = Constants::RESPONSE
  _insts = JSON.parse(params["instruction"])
  _guest = Guest.first(:_id => Base64.decode64(req["HTTP_CLIENT_ID"]).to_i)
  _now = Time.now
  if _guest.last_like.nil? || _now.year != _guest.last_like.year || (_now.yday - _guest.last_like.yday) >=1
    _guest.update(:like_times => 6)
  end
  if _guest.like_times == 0
    [200] + _res + [{failed: 5}.to_json]
  else
    _message = Message.first(:message_id => _insts["message_id"])
    _like_guest = Guest.first(:_id => _message.guest_id)
    _message.update(:liked_count => _message.liked_count - 1)
    _like_guest.update(:liked_num => _like_guest.liked_num - 1)
    _guest.update(:like_times => _guest.like_times - 1,
                  :last_like => Time.now)
    _new_thumb = Thumb.new(:guest_id => _guest._id,
                           :message_id => _message.message_id,
                           :isthumbup => false,
                           :thumb_time => Time.now)
    _new_thumb.save
    [200] + _res + [{}.to_json]
  end
end

def show_thumbups(params, req)
  _res = Constants::RESPONSE
  _thumbs = Thumb.all(:guest_id => Base64.decode64(req["HTTP_CLIENT_ID"]).to_i, :isthumbup => true, :order => [ :thumb_id.desc ])
  _num = _thumbs.length
  if _num == 0
    _data = []
  else
    _data = Array.new(_num)
    _thumbs.each_with_index do |thumb, i|
      _message = Message.last(:message_id => thumb.message_id)
      _guest = Guest.last(:_id => _message.guest_id)
      _data[i] = {
        message_id: thumb.message_id,
        guest_id: Base64.encode64(_message.guest_id.to_s),
        name: _guest.name,
        avatar: _guest.avatar,
        content: _message.content,
        send_time: DateTime.parse(_message.send_time.to_s).to_time.to_i,
        liked_count: _message.liked_count,
        thumb_time: DateTime.parse(thumb.thumb_time.to_s).to_time.to_i
      }
    end
  end
  [200] + _res + [{result: _data}.to_json]
end

def show_thumbdowns(params, req)
  _res = Constants::RESPONSE
  _thumbs = Thumb.all(:guest_id => Base64.decode64(req["HTTP_CLIENT_ID"]).to_i, :isthumbup => false, :order => [ :thumb_id.desc ])
  _num = _thumbs.length
  if _num == 0
    _data = []
  else
    _data = Array.new(_num)
    _thumbs.each_with_index do |thumb, i|
      _message = Message.last(:message_id => thumb.message_id)
      _guest = Guest.last(:_id => _message.guest_id)
      _data[i] = {
        message_id: thumb.message_id,
        guest_id: Base64.encode64(_message.guest_id.to_s),
        name: _guest.name,
        avatar: _guest.avatar,
        content: _message.content,
        send_time: DateTime.parse(_message.send_time.to_s).to_time.to_i,
        liked_count: _message.liked_count,
        thumb_time: DateTime.parse(thumb.thumb_time.to_s).to_time.to_i
      }
    end
  end
  [200] + _res + [{result: _data}.to_json]
end

def popular_messages(params, req)
  _res = Constants::RESPONSE
  _popular_messages = Message.all(:limit => 6, :order => [ :liked_count.desc ])
  _num = _popular_messages.length
  if _num == 0
    _data = []
  else
    _data = Array.new(_num)
    _popular_messages.each_with_index do |message, i|
      _guest = Guest.last(:_id => message.guest_id)
      _thumb = Thumb.last(:guest_id => Base64.decode64(req["HTTP_CLIENT_ID"]).to_i, :message_id => message.message_id)
      if _thumb.nil?
        _label = nil
      elsif _thumb.isthumbup
        _label = true
      else
        _label = false
      end
      _data[i] = {
        message_id: message.message_id,
        guest_id: Base64.encode64(message.guest_id.to_s),
        name: _guest.name,
        avatar: _guest.avatar,
        content: message.content,
        send_time: DateTime.parse(message.send_time.to_s).to_time.to_i,
        liked_count: message.liked_count,
        label: _label
      }
    end
  end
  [200] + _res + [{result: _data}.to_json]
end

def popular_guests(params, req)
  _res = Constants::RESPONSE
  _popular_guests = Guest.all(:limit => 6, :order => [ :follower_num.desc ])
  _num = _popular_guests.length
  if _num == 0
    _data = []
  else
    _data = Array.new(_num)
    _popular_guests.each_with_index do |guest, i|
      _data[i] = {
        id: Base64.encode64(guest._id.to_s),
        name: guest.name,
        gender: guest.gender,
        avatar: guest.avatar,
        follower_num: guest.follower_num
      }
    end
  end
  [200] + _res + [{result: _data}.to_json]
end