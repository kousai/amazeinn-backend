module Constants

  GUESTS_LIMIT = 594

  SECRET = 'My$ecretK3y=AMazeInn'

  DIR_RAND = 'rand.txt'

  EXPIRE_TIME = 86399

  DEV_URL = 'http://localhost:4567/'

  PROD_URL = 'https://amazeinn-backend.herokuapp.com/'

  AVATAR_URL = 'static/images/avatar/'

  BG_MUSIC_URL = 'static/music/bg_music/'

  BG_IMAGE_URL = 'static/images/bg_image/'

  RESPONSE = [{"Access-Control-Allow-Origin" => "*",
               "Access-Control-Allow-Headers" => "Origin, X-Requested-With, Content-Type, Accept, CLIENT_ID, REFRESH_TOKEN, ACCESS_TOKEN, REQUEST, ACTION",
               "Access-Control-Allow-Methods" => "POST,GET,OPTIONS",
               "Content-Type" => "application/json;charset=utf-8"}]

  def Constants.calculate_floor(num)
    num/6+1
  end

  def Constants.calculate_room(num)
    (num+1)%6==0?6:(num+1)%6
  end

  def Constants.init_rand(num)
    _nums = Array.new(num)
    0.upto(num-1) { |i| _nums[i] = i }
    _nums.sort! { |x,y| Random.rand() <=> 0.5 }
    File.open("rand.txt", 'w') do |f|
      0.upto(num-1) { |i| f.puts _nums[i] }
    end
    'Complete!'
  end

  def Constants.new_str(len)
    _chars = ("a".."z").to_a + ("A".."Z").to_a + ("0".."9").to_a
    _newstr = ""
    1.upto(len) { |i| _newstr << _chars[rand(_chars.size-1)] }
    _newstr
  end

end