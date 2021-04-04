# frozen_string_literal: true

require "alterity/railtie"

module Alterity
  Configuration = Struct.new(
    :command,
    :host, :port, :database, :username, :password,
    :replicas_dsns_database, :replicas_dsns_table, :replicas_dsns
  )
  CurrentState = Struct.new(:migrating, :disabled)

  class << self
    # User facing features
    def configure
      yield self
    end

    def disable
      @@state.disabled = true
      yield
    ensure
      @@state.disabled = false
    end

    # User facing configurable
    def command=(new_command)
      @@config.command = new_command
    end

    def replicas_dsns_table(database:, table:, dsns:)
      return ArgumentError.new("database & table must be present") if database.blank? || table.blank?

      @@config.replicas_dsns_database = database
      @@config.replicas_dsns_table = table
      @@config.replicas_dsns = dsns.uniq.map do |dsn|
        parts = dsn.split(",")
        # automatically add default port
        parts << "P=3306" unless parts.any? { |dsn| dsn.start_with?("P=") }
        # automatically remove master
        next if parts.include?("h=#{@@config.host}") && parts.include?("P=#{@@config.port}")
        parts.join(",")
      end.compact
    end

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

    # accessors
    def config
      @@config
    end

    # utilities
    def reset_state_and_configuration
      @@config = Configuration.new
      @@state = CurrentState.new

      @@config.command = -> (config, altered_table, alter_argument) {
        <<~SHELL.squish
        pt-online-schema-change
          -h #{config.host}
          -P #{config.port}
          -u #{config.username}
          --password=#{config.password}
          --execute
          D=#{config.database},t=#{altered_table}
          --alter #{alter_argument}
        SHELL
      }
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

  module Mysql2Additions
    def query(sql, options = {})
      Alterity.process_sql_query(sql) { super(sql, options) }
    end
  end
end
