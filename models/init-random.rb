nums = Array.new(594)
for i in 0..593
  nums[i] = i
end
nums.sort! { |x,y| Random.rand() <=> 0.5 }
File.open("rand.txt", 'w') do |f| 
  for i in 0..593
    f.puts nums[i]
  end
end