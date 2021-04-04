# frozen_string_literal: true

require "alterity/configuration"
require "alterity/mysql_client_additions"
require "alterity/railtie"

module Alterity
  class << self
    # mysql2 gem interface
    def process_sql_query(sql, &block)
      case sql.strip
      when /^alter table (?<table>.+?) (?<updates>.+)/i
        execute_alter($~[:table], $~[:updates])
      when /^create index (?<index>.+?) on (?<table>.+?) (?<updates>.+)/i
        execute_alter($~[:table], "ADD INDEX #{$~[:index]} #{$~[:updates]}")
      when /^create unique index (?<index>.+?) on (?<table>.+?) (?<updates>.+)/i
        execute_alter($~[:table], "ADD UNIQUE INDEX #{$~[:index]} #{$~[:updates]}")
      when /^drop index (?<index>.+?) on (?<table>.+)/i
        execute_alter($~[:table], "DROP INDEX #{$~[:index]}")
      else
        block.call
      end
    end

    # hooks
    def before_running_migrations
      @@state.migrating = true
      set_database_config
      prepare_replicas_dsns_table
    end

    def after_running_migrations
      @@state.migrating = false
    end

    private

    # TODO test all kinds of queries, including FK related queries
    def execute_alter(table, updates)
      altered_table = table.delete('`')
      alter_argument = %("#{updates.gsub('"', '\\"').gsub('`', '\\\`')}")
      prepared_command = @@config.command.call(@@config, altered_table, alter_argument).gsub(/\n/, "\\\n")
      puts "[Alterity] Will execute: #{prepared_command}"
      system(prepared_command)
    end

    def set_database_config
      db_config_hash = ActiveRecord::Base.connection_db_config.configuration_hash
      [:host, :port, :database, :username, :password].each do |key|
        @@config[key] = db_config_hash[key]
      end
    end

    # Optional: Automatically set up table PT-OSC will monitor for replica lag.
    def prepare_replicas_dsns_table
      return if @@config.replicas_dsns_table.blank?

      database = @@config.replicas_dsns_database
      table = "#{database}.#{@@config.replicas_dsns_table}"
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
      return if @@config.replicas_dsns.empty?

      connection.execute <<~SQL
        INSERT INTO #{table} (dsn)
         #{@@config.replicas_dsns.map { |dsn| "('#{dsn}')" }.join(",")}
      SQL
    end
  end

  reset_state_and_configuration
end
