require 'data_mapper'
DataMapper.setup(:default, ENV['DATABASE_URL'] || "sqlite3://#{Dir.pwd}/amazeinn.db")

class Room
    include DataMapper::Resource
    property :room_id,          Serial
    property :room_floor,       Integer
    property :room_num,         Integer
    property :isempty,          Boolean, :default  => true
  end
DataMapper.finalize

for i in 0..593
  @init = Room.new(:room_floor => (i/6+1), :room_num => ((i+1)%6==0?6:(i+1)%6))
  @init.save
  puts 'floor'+(i/6+1).to_s+'  room'+((i+1)%6==0?6:(i+1)%6).to_s+'  OK!'
end