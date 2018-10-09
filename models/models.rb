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
  property :avatar,           Text
  property :bg_music,         Text
  property :bg_image,         Text

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

class Thumb
  include DataMapper::Resource
  property :thumb_id,         Serial
  property :guest_id,         Integer
  property :message_id,       Integer
  property :isthumbup,        Boolean, :default  => true
  property :thumb_time,       DateTime, :required => true
end

class Mail
  include DataMapper::Resource
  property :mail_id,          Serial
  property :initiator,        Integer
  property :acceptor,         Integer
  property :content,          Text
  property :send_time,        DateTime, :required => true
end