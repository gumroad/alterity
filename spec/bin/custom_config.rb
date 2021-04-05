# frozen_string_literal: true

Alterity.configure do |config|
  config.command = lambda { |altered_table, alter_argument|
    string = config.to_h.slice(
      *%i[host port username database replicas_dsns_database replicas_dsns_table replicas_dsns]
    ).to_s
    system("echo '#{string}' > /tmp/custom_command_result.txt")
    system("echo '#{altered_table}' >> /tmp/custom_command_result.txt")
    system("echo '#{alter_argument}' >> /tmp/custom_command_result.txt")
  }

  config.replicas(
    database: "percona",
    table: "replicas_dsns",
    dsns: [
      "h=host1",
      "h=host2"
    ]
  )
end
