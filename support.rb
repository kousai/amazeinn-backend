module Something

  GUESTS_LIMIT = 594

  SECRET = 'my$ecretK3y=AMazeInn'

  DIR_RAND = 'rand.txt'

  EXPIRE_TIME = 86399

  # MAIN_URL = 'http://localhost:4567/'

  MAIN_URL = 'https://amazeinn-backend.herokuapp.com/'

  DIR_AVATAR = 'static/images/avatar/'

  DIR_BG_MUSIC = 'static/music/bg_music/'

  DIR_BG_IMAGE = 'static/images/bg_image/'

  RESPONSE = [{"Access-Control-Allow-Origin" => "*", "Access-Control-Allow-Headers" => "Origin, X-Requested-With, Content-Type, Accept, CLIENT_ID, REFRESH_TOKEN, ACCESS_TOKEN, REQUEST, ACTION", "Access-Control-Allow-Methods" => "POST,GET,OPTIONS", "Content-Type" => "application/json;charset=utf-8"}]

  def Something.calculate_floor(num)
    num/6+1
  end

  def Something.calculate_room(num)
    (num+1)%6==0?6:(num+1)%6
  end

  def Something.init_rand(num)
    @nums = Array.new(num)
    0.upto(num-1) { |i| @nums[i] = i }
    @nums.sort! { |x,y| Random.rand() <=> 0.5 }
    File.open("rand.txt", 'w') do |f|
      0.upto(num-1) { |i| f.puts @nums[i] }
    end
    'Complete!'
  end

  def Something.new_str(len)
    @chars = ("a".."z").to_a + ("A".."Z").to_a + ("0".."9").to_a
    @newstr = ""
    1.upto(len) { |i| @newstr << @chars[rand(@chars.size-1)] }
    return @newstr
  end

end