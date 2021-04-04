# frozen_string_literal: true

require "alterity/railtie"

module Alterity
  Configuration = Struct.new(
    :command,
    :host, :port, :database, :username, :password,
    :replicas_dsns_database, :replicas_dsns_table,
  )
  CurrentState = Struct.new(:migrating, :disabled)
  @@config = Configuration.new
  @@state = CurrentState.new

  @@config.command = -> (config, altered_table, alter_argument) {
    %(pt-online-schema-change
      -h #{config.host}
      -P #{config.port}
      -u #{config.username}
      --password=#{config.password}
      --execute
      D=#{config.database},t=#{altered_table}
      --alter #{alter_argument})
  }

  class << self
    # User facing
    def configure
      yield self
    end

    def disable
      @@state.disabled = true
      yield
    ensure
      @@state.disabled = false
    end

    # Configurable
    def replicas_dsns_table(:database, :table, :dsns)
      # TODO
    end

    def command=(new_command)
      @@config.command = new_command
    end

    def process_sql_query(sql, &block)
      case sql.strip
      when /^alter table (?<table>.+?) (?<updates>.+)/i
        @@config.command.call(@@config, $~[:table], $~[:updates])
      when /^create index (?<index>.+?) on (?<table>.+?) (?<updates>.+)/i
        @@config.command.call(@@config, $~[:table], "ADD INDEX #{$~[:index]} #{$~[:updates]}")
      when /^create unique index (?<index>.+?) on (?<table>.+?) (?<updates>.+)/i
        @@config.command.call(@@config, $~[:table], "ADD UNIQUE INDEX #{$~[:index]} #{$~[:updates]}")
      when /^drop index (?<index>.+?) on (?<table>.+)/i
        @@config.command.call(@@config, $~[:table], "DROP INDEX #{$~[:index]}")
      else
        block.call
      end
    end

    def before_running_migrations
      @@state.migrating = true
      set_database_config
      prepare_replicas_dsns_table
    end

    def after_running_migrations
      @@state.migrating = false
    end

    def config
      @@config
    end

    def state
      @@state
    end

    private

    def set_database_config
      db_config_hash = ActiveRecord::Base.connection_db_config.configuration_hash
      [:host, :port, :database, :username, :password].each do |key|
        @@config[key] = db_config_hash[key]
      end
    end

    # Optional: Automatically set up table PT-OSC will monitor for replica lag.
    def prepare_replicas_dsns_table
      # TODO: x
    end
  end

  module Mysql2Additions
    def query(sql, options = {})
      Alterity.process_sql_query(sql) { super(sql, options) }
    end
  end
end
