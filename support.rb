module Something

  GUESTS_LIMIT = 594

  SECRET = 'my$ecretK3y=AMazeInn'

  DIR_RAND = 'rand.txt'

  EXPIRE_TIME = 86399

  MAIN_URL = 'http://localhost:4567/'

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

end