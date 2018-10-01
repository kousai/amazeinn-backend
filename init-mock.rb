require './main'

for i in 0..99
    @name = (i+100).to_s
    @obj = {"username" => @name, "password" => "111111111"}
    @res = guest_create(@obj)
    puts 'mock'+i.to_s+'  OK! '+@res.to_s
end