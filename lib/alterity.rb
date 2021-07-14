# frozen_string_literal: true

require "rails"
require "alterity/configuration"
require "alterity/mysql_client_additions"
require "alterity/railtie"

class Alterity
  class << self
    def process_sql_query(sql, &block)
      case sql.tr("\n", " ").strip
      when /^alter\s+table\s+(?<table>.+?)\s+(?<updates>.+)/i
        table = $~[:table]
        updates = $~[:updates]
        if updates.split(",").all? { |s| s =~ /^\s*drop\s+foreign\s+key/i } ||
           updates.split(",").all? { |s| s =~ /^\s*add\s+constraint/i }
          block.call
        elsif updates =~ /drop\s+foreign\s+key/i || updates =~ /add\s+constraint/i
          # ADD CONSTRAINT / DROP FOREIGN KEY have to go to the original table,
          # other alterations need to got to the new table.
          raise "[Alterity] Can't change a FK and do something else in the same query. Split it."
        else
          execute_alter(table, updates)
        end
      when /^create\s+index\s+(?<index>.+?)\s+on\s+(?<table>.+?)\s+(?<updates>.+)/i
        execute_alter($~[:table], "ADD INDEX #{$~[:index]} #{$~[:updates]}")
      when /^create\s+unique\s+index\s+(?<index>.+?)\s+on\s+(?<table>.+?)\s+(?<updates>.+)/i
        execute_alter($~[:table], "ADD UNIQUE INDEX #{$~[:index]} #{$~[:updates]}")
      when /^drop\s+index\s+(?<index>.+?)\s+on\s+(?<table>.+)/i
        execute_alter($~[:table], "DROP INDEX #{$~[:index]}")
      else
        block.call
      end
    end

    # hooks
    def before_running_migrations
      require "open3"
      state.migrating = true
      set_database_config
      prepare_replicas_dsns_table
    end

    def after_running_migrations
      state.migrating = false
    end

    private

    def execute_alter(table, updates)
      altered_table = table.delete("`")
      alter_argument = %("#{updates.gsub('"', '\\"').gsub('`', '\\\`')}")
      prepared_command = config.command.call(altered_table, alter_argument).to_s.gsub(/\n/, "\\\n")
      puts "[Alterity] Will execute: #{prepared_command}"
      config.before_command&.call(prepared_command)

      result_str = +""
      exit_status = nil
      Open3.popen2e(prepared_command) do |_stdin, stdout_and_stderr, wait_thr|
        stdout_and_stderr.each do |line|
          puts line
          result_str << line
          config.on_command_output&.call(line)
        end
        exit_status = wait_thr.value
        config.after_command&.call(wait_thr.value.to_i)
      end

      raise("[Alterity] Command failed. Full output: #{result_str}") unless exit_status.success?
    end

    def set_database_config
      db_config_hash = ActiveRecord::Base.connection_db_config.configuration_hash
      %i[host port database username password].each do |key|
        config[key] = db_config_hash[key]
      end
    end

    # Optional: Automatically set up table PT-OSC will monitor for replica lag.
    def prepare_replicas_dsns_table
      return if config.replicas_dsns_table.blank?

      dsns = config.replicas_dsns.dup
      # Automatically remove master
      dsns.reject! { |dsn| dsn.split(",").include?("h=#{config.host}") }

      database = config.replicas_dsns_database
      table = "#{database}.#{config.replicas_dsns_table}"
      connection = ActiveRecord::Base.connection
      connection.execute "CREATE DATABASE IF NOT EXISTS #{database}"
      connection.execute <<~SQL
        CREATE TABLE IF NOT EXISTS #{table} (
          id INT(11) NOT NULL AUTO_INCREMENT,
          parent_id INT(11) DEFAULT NULL,
          dsn VARCHAR(255) NOT NULL,
          PRIMARY KEY (id)
        ) ENGINE=InnoDB
      SQL
      connection.execute "TRUNCATE #{table}"
      return if dsns.empty?

      connection.execute <<~SQL
        INSERT INTO #{table} (dsn) VALUES
         #{dsns.map { |dsn| "('#{dsn}')" }.join(',')}
      SQL
    end
  end

  reset_state_and_configuration
end
