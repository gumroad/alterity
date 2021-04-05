# frozen_string_literal: true

Alterity.configure do |config|
  config.command = lambda { |altered_table, alter_argument|
    parts = ["pt-online-schema-change"]
    parts << %(-h "#{config.host}") if config.host.present?
    parts << %(-P "#{config.port}") if config.port.present?
    parts << %(-u "#{config.username}") if config.username.present?
    parts << %(--password "#{config.password.gsub('"', '\\"')}") if config.password.present?
    parts << "--execute"
    parts << "D=#{config.database},t=#{altered_table}"
    parts << "--alter #{alter_argument}"
    parts.join(" ")
  }
end
