# frozen_string_literal: true

if File.exist?("/tmp/custom_command_result.txt")
  puts "=> disabled state does not work"
  exit(1)
end
