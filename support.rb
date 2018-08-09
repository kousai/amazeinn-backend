module Something

  GUESTS_LIMIT = 594

  SECRET = 'my$ecretK3y=AMazeInn'

  DIR_RAND = './models/rand.txt'

  DIR_AVATAR = 'static/images/avatar/'

  DIR_BG_MUSIC = 'static/music/bg_music/'

  DIR_BG_IMAGE = 'static/images/bg_image/'


  def Something.calculate_floor(num)
    num/6+1
  end

  def Something.calculate_room(num)
    (num+1)%6==0?6:(num+1)%6
  end

  def Something.message_checkin_full
    [400, {"Content-Type" => "text/plain"}, {message:'Sorry! No empty rooms!'}.to_json]
  end

  def Something.message_checkin_success
    [200, {"Content-Type" => "text/plain"}, {message:'Check-in successful!'}.to_json]
  end

  def Something.message_checkin_exist(id)
    [400, {"Content-Type" => "text/plain"}, {message:'Sorry! ID "' + id + '" already exists!'}.to_json]
  end

  def Something.message_wrong_password
    [400, {"Content-Type" => "text/plain"}, {message:'Sorry! Wrong password!'}.to_json]
  end

  def Something.message_login_not_exist(id)
    [400, {"Content-Type" => "text/plain"}, {message:'Sorry! ID "'+ id.to_s + '" does not exist!'}.to_json]
  end

  def Something.message_login_success(res)
    [200, {"Content-Type" => "text/plain"}, {message:'Enter successful!', result:res}.to_json]
  end

  def Something.message_request_fail
    [400, {"Content-Type" => "text/plain"}, {message:'Invalid request!'}.to_json]
  end

  def Something.message_token_fail
    [400, {"Content-Type" => "text/plain"}, {message:'Request fails!'}.to_json]
  end

  def Something.message_token_update_success(res)
    [200, {"Content-Type" => "text/plain"}, {message:'Update token successful!', result:res}.to_json]
  end

  def Something.message_leave_success
    [200, {"Content-Type" => "text/plain"}, {message:'Leave successful!'}.to_json]
  end

  def Something.message_checkout_success
    [200, {"Content-Type" => "text/plain"}, {message:'Check-out successful!'}.to_json]
  end

  def Something.message_enter_index(res)
    [200, {"Content-Type" => "text/plain"}, {message:'Enter successful!', result:res}.to_json]
  end

  def Something.message_enter_room(res)
    [200, {"Content-Type" => "text/plain"}, {message:'Enter room successful!', result:res}.to_json]
  end

  def Something.message_edit_password_success
    [200, {"Content-Type" => "text/plain"}, {message:'Edit password successful!'}.to_json]
  end

  def Something.message_edit_password_fail
    [400, {"Content-Type" => "text/plain"}, {message:'You entered a wrong password!'}.to_json]
  end

  def Something.message_edit_profile_success
    [200, {"Content-Type" => "text/plain"}, {message:'Edit profile successful!'}.to_json]
  end

  def Something.message_upload_file_success
    [200, {"Content-Type" => "text/plain"}, {message:'Upload file successful!'}.to_json]
  end

  def Something.message_send_message(res)
    [200, {"Content-Type" => "text/plain"}, {message:'Send message successful!', result:res}.to_json]
  end

  def Something.message_show_message(res)
    [200, {"Content-Type" => "text/plain"}, {message:'Show message successful!', result:res}.to_json]
  end

  def Something.message_knock_door(res)
    [200, {"Content-Type" => "text/plain"}, {message:'Knock door successful!', result:res}.to_json]
  end

  def Something.message_follow_guest
    [200, {"Content-Type" => "text/plain"}, {message:'Follow guest successful!'}.to_json]
  end

  def Something.message_unfollow_guest
    [200, {"Content-Type" => "text/plain"}, {message:'Unfollow guest successful!'}.to_json]
  end

  def Something.message_show_follows(res)
    [200, {"Content-Type" => "text/plain"}, {message:'Show follows successful!', result:res}.to_json]
  end

  def Something.message_show_followers(res)
    [200, {"Content-Type" => "text/plain"}, {message:'Show followers successful!', result:res}.to_json]
  end

  def Something.message_like_message_success
    [200, {"Content-Type" => "text/plain"}, {message:'Like message successful!'}.to_json]
  end

  def Something.message_dislike_message_success
    [200, {"Content-Type" => "text/plain"}, {message:'Dislike message successful!'}.to_json]
  end

  def Something.message_no_like_time
    [400, {"Content-Type" => "text/plain"}, {message:'No like-time!'}.to_json]
  end

  def Something.message_popular_messages(res)
    [200, {"Content-Type" => "text/plain"}, {message:'Show popular message successful!', result:res}.to_json]
  end

  def Something.message_popular_guests(res)
    [200, {"Content-Type" => "text/plain"}, {message:'Show popular guest successful!', result:res}.to_json]
  end

end