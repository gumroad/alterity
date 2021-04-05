# frozen_string_literal: true

result = File.read("/tmp/custom_command_result.txt").downcase.strip

expected_result = %({:host=>"127.0.0.1", :port=>nil, :username=>"root", :database=>"alterity_test", :replicas_dsns_database=>"percona", :replicas_dsns_table=>"replicas_dsns", :replicas_dsns=>["h=host1,P=3306", "h=host2,P=3306"]}
shirts
"ADD \\`color2\\` VARCHAR(255)").downcase.strip

puts "Expected custom config result:"
puts expected_result
p expected_result.chars.map(&:hex)

puts "Custom config result:"
puts result
p result.chars.map(&:hex)

if result != expected_result
  puts "=> mismatch"
  exit(1)
end
