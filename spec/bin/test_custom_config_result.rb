# frozen_string_literal: true

result = File.read("/tmp/custom_command_result.txt").downcase.strip

expected_result = %({:host=>"127.0.0.1", :port=>nil, :username=>"root", :database=>"alterity_test", :replicas_dsns_database=>"percona", :replicas_dsns_table=>"replicas_dsns", :replicas_dsns=>["h=host1,P=3306", "h=host2,P=3306", "h=127.0.0.1,P=3306"]}
shirts
"ADD \\`color2\\` VARCHAR(255)").downcase.strip

puts "Expected custom config result:"
puts expected_result
p expected_result.chars.map(&:hex)

puts "Custom config result:"
puts result
p result.chars.map(&:hex)

if result != expected_result
  puts "=> mismatched result"
  exit(1)
end


result = File.read("/tmp/before_command.txt")
if result != "ls /"
  puts "=> mismatched before_command"
  exit(1)
end

result = File.read("/tmp/on_command_output.txt")
if !result.include?("var")
  puts "=> mismatched on_command_output"
  exit(1)
end

result = File.read("/tmp/after_command.txt")
if result.strip != "0"
  puts "=> mismatched after_command"
  exit(1)
end
