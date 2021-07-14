# frozen_string_literal: true

Alterity.configure do |config|
  config.command = lambda { |altered_table, alter_argument|
    string = config.to_h.slice(
      *%i[host port username database replicas_dsns_database replicas_dsns_table replicas_dsns]
    ).to_s
    system("echo '#{string}' > /tmp/custom_command_result.txt")
    system("echo '#{altered_table}' >> /tmp/custom_command_result.txt")
    system("echo '#{alter_argument}' >> /tmp/custom_command_result.txt")
    "ls /"
  }

  config.replicas(
    database: "percona",
    table: "replicas_dsns",
    dsns: [
      "h=host1",
      "h=host2",
      # we may encounter an app where the replica host is actually pointing to master;
      # pt-osc doesn't deal well with this and will wait forever.
      # So we're testing here that Alterity will detect that this is master (same as config.host),
      # and will not insert it into the `replicas_dsns` table.
      "h=#{ENV['MYSQL_HOST']}"
    ]
  )

  config.before_command = lambda do |command|
    File.new("/tmp/before_command.txt", "w").syswrite(command)
  end

  config.on_command_output = lambda do |output|
    File.new("/tmp/on_command_output.txt", "w+").syswrite(output)
  end

  config.after_command = lambda do |exit_status|
    File.new("/tmp/after_command.txt", "w").syswrite(exit_status)
  end
end
