require 'data_mapper'
require 'dm-migrations'
require_relative 'models'

DataMapper.setup(:default, ENV['DATABASE_URL'] || "sqlite3://#{Dir.pwd}/db/amazeinn.db")
DataMapper.finalize
DataMapper.auto_upgrade!