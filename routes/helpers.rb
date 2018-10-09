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
    @init = Room.new(:room_floor => Constants.calculate_floor(i), :room_num => Constants.calculate_room(i))
    @init.save
    puts "floor#{Constants.calculate_floor(i).to_s}  room#{Constants.calculate_room(i).to_s}  OK!"
  }
  'Complete!'
end

def init_mock(num)
  0.upto(num-1) { |i|
    @name = Constants.new_str(6)
    @obj = {"username" => @name, "password" => "111111111"}
    @res = guest_create(@obj)
    @guest = Guest.last(:name => @name)
    @genders = ['Male', 'Female', 'Other']
    @guest.update(:isreal => false, :gender => @genders[Random.rand(3)-1])
    puts "mock#{(i+1).to_s}: #{@name}  Created!"
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
  @res = Constants::RESPONSE
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
      if @newguest._id <= Constants::GUESTS_LIMIT
        @arr = IO.readlines(Constants::DIR_RAND)
        @newguest.update(
          :floor_num => Constants.calculate_floor(@arr[@newguest._id-1].chomp.to_i),
          :room_num => Constants.calculate_room(@arr[@newguest._id-1].chomp.to_i))
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
  @res = Constants::RESPONSE
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
      :refresh_token => @refresh_token,
      :access_token => @access_token,
      :last_login => Time.now,
      :last_refresh => Time.now)
    @data = {
      client_id: Base64.encode64(@guest._id.to_s),
      name: @guest.name,
      refresh_token: @guest.refresh_token,
      access_token: @guest.access_token,
      gender: @guest.gender,
      avatar: @guest.avatar
    }
    [200] + @res + [{result: @data}.to_json]
  else
    [200] + @res + [{failed: 4}.to_json]
  end
end

def guest_leave(obj)
  @res = Constants::RESPONSE
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
  @res = Constants::RESPONSE
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
  @res = Constants::RESPONSE
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
  @res = Constants::RESPONSE
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
    else [400] + @res + [{}.to_json]
  end
end

def enter_index(params, req)
  @res = Constants::RESPONSE
  @guest = Guest.first(:_id => Base64.decode64(req["HTTP_CLIENT_ID"]).to_i)
  @mems = Array.new(6)
  for i in 0..5
    @mem = Guest.first(:floor_num => @guest.game_floor, :room_num => i+1)
    if @mem.nil?
      @mems[i] = {
        id: nil,
        name: nil,
        gender: nil,
        avatar: nil,
        isempty: true
      }
    else
      @mems[i] = {
        id: Base64.encode64(@mem._id.to_s),
        name: @mem.name,
        gender: @mem.gender,
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
  @res = Constants::RESPONSE
  @guest = Guest.first(:_id => Base64.decode64(req["HTTP_CLIENT_ID"]).to_i)
  @mess = Message.last(:guest_id => @guest._id)
  @recent_message = {}
  if @mess.nil?
    @recent_message = nil
  else
    @recent_message = {
      message_id: @mess.message_id,
      content: @mess.content,
      send_time: DateTime.parse(@mess.send_time.to_s).to_time.to_i,
      liked_count: @mess.liked_count
    }
  end
  @data = {
    name: @guest.name,
    created_on: DateTime.parse(@guest.created_on.to_s).to_time.to_i,
    last_login: DateTime.parse(@guest.last_login.to_s).to_time.to_i,
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
    like_times: @guest.like_times,
    message: @recent_message,
    follows_label: false,
    followed_label: false
  }
  [200] + @res + [{result: @data}.to_json]
end

def knock_door(params, req)
  @res = Constants::RESPONSE
  @ego = Guest.first(:_id => Base64.decode64(req["HTTP_CLIENT_ID"]).to_i)
  @insts = JSON.parse(params["instruction"])
  @guest = Guest.first(:_id => Base64.decode64(@insts["id"]).to_i)
  @mess = Message.last(:guest_id => @guest._id)
  @recent_message = {}
  if @mess.nil?
    @recent_message = nil
  else
    @thumb = Thumb.last(:guest_id => Base64.decode64(req["HTTP_CLIENT_ID"]).to_i, :message_id => @mess.message_id)
    if @thumb.nil?
      @label = nil
    elsif @thumb.isthumbup
      @label = 0
    else
      @label = 1
    end
    @recent_message = {
      message_id: @mess.message_id,
      content: @mess.content,
      send_time: DateTime.parse(@mess.send_time.to_s).to_time.to_i,
      liked_count: @mess.liked_count,
      label: @label
    }
  end
  @follows_contact = Contact.last(:initiator => @ego._id, :acceptor => @guest._id)
  if @follows_contact.nil?
    @follows_label = false
  else
    @follows_label = true
  end
  @followed_contact = Contact.last(:initiator => @guest._id, :acceptor => @ego._id)
  if @followed_contact.nil?
    @followed_label = false
  else
    @followed_label = true
  end
  @data = {
    name: @guest.name,
    created_on: DateTime.parse(@guest.created_on.to_s).to_time.to_i,
    last_login: @guest.last_login ? DateTime.parse(@guest.last_login.to_s).to_time.to_i : nil,
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
    like_times: @guest.like_times,
    message: @recent_message,
    follows_label: @follows_label,
    followed_label: @followed_label
  }
  [200] + @res + [{result: @data}.to_json]
end

def edit_password(params, req)
  @res = Constants::RESPONSE
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
  @res = Constants::RESPONSE
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
    else [400] + @res + [{}.to_json]
  end
  [200] + @res + [{}.to_json]
end

def upload_file(params, req)
  @res = Constants::RESPONSE
  @guest = Guest.first(:_id => Base64.decode64(req["HTTP_CLIENT_ID"]).to_i)
  @tempfile = params["file"]["tempfile"]
  @filename = params["file"]["filename"]
  @now = Time.now
  @savename = @guest._id.to_s + '_' + @now.to_i.to_s + '_' + @now.usec.to_s + File.extname(@filename)
  case req["HTTP_ACTION"]
    when "avatar" then @dir = File.join File.dirname(__FILE__), '..', 'static', 'images', 'avatar'
    when "bg_music" then @dir = File.join File.dirname(__FILE__), '..', 'static', 'music', 'bg_music'
    when "bg_image" then @dir = File.join File.dirname(__FILE__), '..', 'static', 'images', 'bg_image'
  end
  @target = File.join(@dir, @savename)
  FileUtils.mkdir_p(@dir) unless File.exist?(@dir)
  File.open(@target, 'w+') {|f| f.write File.read(@tempfile) }
  case req["HTTP_ACTION"]
    when "avatar" then @url = base_url() + Constants::AVATAR_URL + @savename
    when "bg_music" then @url = base_url() + Constants::BG_MUSIC_URL + @savename
    when "bg_image" then @url = base_url() + Constants::BG_IMAGE_URL + @savename
  end
  @guest.update(req["HTTP_ACTION"] => @url)
  [200] + @res + [{}.to_json]
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
  @res = Constants::RESPONSE
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
  @res = Constants::RESPONSE
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
  @res = Constants::RESPONSE
  @guest = Guest.first(:_id => Base64.decode64(req["HTTP_CLIENT_ID"]).to_i)
  @follows = Contact.all(:initiator => @guest._id, :order => [ :contact_id.desc ])
  if @guest.follow_num == 0
    @data = []
  else
    @data = Array.new(@guest.follow_num)
    @follows.each_with_index do |follow, i|
      @follow_guest = Guest.first(:_id => follow.acceptor)
      @data[i] = {
        id: Base64.encode64(@follow_guest._id.to_s),
        name: @follow_guest.name,
        gender: @follow_guest.gender,
        avatar: @follow_guest.avatar,
        follow_time: DateTime.parse(follow.build_time.to_s).to_time.to_i
      }
    end
  end
  [200] + @res + [{result: @data}.to_json]
end

def show_followers(params, req)
  @res = Constants::RESPONSE
  @guest = Guest.first(:_id => Base64.decode64(req["HTTP_CLIENT_ID"]).to_i)
  @followers = Contact.all(:acceptor => @guest._id, :order => [ :contact_id.desc ])
  if @guest.follower_num == 0
    @data = []
  else
    @data = Array.new(@guest.follower_num)
    @followers.each_with_index do |follower, i|
      @follower_guest = Guest.first(:_id => follower.initiator)
      @data[i] = {
        id: Base64.encode64(@follower_guest._id.to_s),
        name: @follower_guest.name,
        gender: @follower_guest.gender,
        avatar: @follower_guest.avatar,
        follow_time: DateTime.parse(follower.build_time.to_s).to_time.to_i
      }
    end
  end
  [200] + @res + [{result: @data}.to_json]
end

def send_message(params, req)
  @res = Constants::RESPONSE
  @guest = Guest.first(:_id => Base64.decode64(req["HTTP_CLIENT_ID"]).to_i)
  @insts = JSON.parse(params["instruction"])
  @new_message = Message.new(
    :guest_id => @guest._id,
    :content => @insts["message"],
    :send_time => Time.now)
  @new_message.save
  @guest.update(:message_num => @guest.message_num + 1)
  [200] + @res + [{}.to_json]
end

def show_messages(params, req)
  @res = Constants::RESPONSE
  @guest = Guest.first(:_id => Base64.decode64(req["HTTP_CLIENT_ID"]).to_i)
  @messages = Message.all(:guest_id => @guest._id, :order => [ :message_id.desc ])
  if @guest.message_num == 0
    @data = []
  else
    @data = Array.new(@guest.message_num)
    @messages.each_with_index do |message, i|
      @data[i] = {
        message_id:message.message_id,
        content: message.content,
        send_time: DateTime.parse(message.send_time.to_s).to_time.to_i,
        liked_count: message.liked_count
      }
    end
  end
  [200] + @res + [{result: @data}.to_json]
end

def like_message(params, req)
  @res = Constants::RESPONSE
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
    @new_thumb = Thumb.new(:guest_id => @guest._id,
                           :message_id => @message.message_id,
                           :thumb_time => Time.now)
    @new_thumb.save
    [200] + @res + [{}.to_json]
  end
end

def dislike_message(params, req)
  @res = Constants::RESPONSE
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
    @new_thumb = Thumb.new(:guest_id => @guest._id,
                           :message_id => @message.message_id,
                           :isthumbup => false,
                           :thumb_time => Time.now)
    @new_thumb.save
    [200] + @res + [{}.to_json]
  end
end

def show_thumbups(params, req)
  @thumbs = Thumb.all(:guest_id => Base64.decode64(req["HTTP_CLIENT_ID"]).to_i, :isthumbup => true, :order => [ :thumb_id.desc ])
  @num = @thumbs.length
  if @num == 0
    @data = []
  else
    @data = Array.new(@num)
    @thumbs.each_with_index do |thumb, i|
      @message = Message.last(:message_id => thumb.message_id)
      @guest = Guest.last(:_id => @message.guest_id)
      @data[i] = {
        message_id: thumb.message_id,
        guest_id: Base64.encode64(@message.guest_id.to_s),
        name: @guest.name,
        avatar: @guest.avatar,
        content: @message.content,
        send_time: DateTime.parse(@message.send_time.to_s).to_time.to_i,
        liked_count: @message.liked_count,
        thumb_time: DateTime.parse(thumb.thumb_time.to_s).to_time.to_i
      }
    end
  end
  [200] + @res + [{result: @data}.to_json]
end

def show_thumbdowns(params, req)
  @thumbs = Thumb.all(:guest_id => Base64.decode64(req["HTTP_CLIENT_ID"]).to_i, :isthumbup => false, :order => [ :thumb_id.desc ])
  @num = @thumbs.length
  if @num == 0
    @data = []
  else
    @data = Array.new(@num)
    @thumbs.each_with_index do |thumb, i|
      @message = Message.last(:message_id => thumb.message_id)
      @guest = Guest.last(:_id => @message.guest_id)
      @data[i] = {
        message_id: thumb.message_id,
        guest_id: Base64.encode64(@message.guest_id.to_s),
        name: @guest.name,
        avatar: @guest.avatar,
        content: @message.content,
        send_time: DateTime.parse(@message.send_time.to_s).to_time.to_i,
        liked_count: @message.liked_count,
        thumb_time: DateTime.parse(thumb.thumb_time.to_s).to_time.to_i
      }
    end
  end
  [200] + @res + [{result: @data}.to_json]
end

def popular_messages(params, req)
  @res = Constants::RESPONSE
  @popular_messages = Message.all(:limit => 6, :order => [ :liked_count.desc ])
  @num = @popular_messages.length
  if @num == 0
    @data = []
  else
    @data = Array.new(@num)
    @popular_messages.each_with_index do |message, i|
      @guest = Guest.last(:_id => message.guest_id)
      @thumb = Thumb.last(:guest_id => Base64.decode64(req["HTTP_CLIENT_ID"]).to_i, :message_id => message.message_id)
      if @thumb.nil?
        @label = nil
      elsif @thumb.isthumbup
        @label = true
      else
        @label = false
      end
      @data[i] = {
        message_id: message.message_id,
        guest_id: Base64.encode64(message.guest_id.to_s),
        name: @guest.name,
        avatar: @guest.avatar,
        content: message.content,
        send_time: DateTime.parse(message.send_time.to_s).to_time.to_i,
        liked_count: message.liked_count,
        label: @label
      }
    end
  end
  [200] + @res + [{result: @data}.to_json]
end

def popular_guests(params, req)
  @res = Constants::RESPONSE
  @popular_guests = Guest.all(:limit => 6, :order => [ :follower_num.desc ])
  @num = @popular_guests.length
  if @num == 0
    @data = []
  else
    @data = Array.new(@num)
    @popular_guests.each_with_index do |guest, i|
      @data[i] = {
        id: Base64.encode64(guest._id.to_s),
        name: guest.name,
        gender: guest.gender,
        avatar: guest.avatar,
        follower_num: guest.follower_num
      }
    end
  end
  [200] + @res + [{result: @data}.to_json]
end