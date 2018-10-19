# amazeinn-backend

Ruby + Sinatra

Deployed on Heroku :
  https://amazeinn-backend.herokuapp.com

RESTful API :
  https://amazeinn-backend.herokuapp.com/api

Front-end :
  https://github.com/kousai/amazeinn-frontend

You can see the website here :
  https://kousai.github.io/amazeinn

To deploy it on Heroku, this tutorial will help you :
  https://devcenter.heroku.com/articles/getting-started-with-ruby

If already deployed on Heroku, in terminal :
  heroku run console

To initialize data, in console :
  require './main'
  init_room(num) # To initialize a specified amount of rooms. You must initialize these rooms 
  init_mock(num) # To initialize a specified amount of mock guests. Not necessary

Then exit the console of Heroku, in terminal :
  heroru open
