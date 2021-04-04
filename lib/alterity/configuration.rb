# frozen_string_literal: true

class Alterity
  Configuration = Struct.new(
    :command,
    :host, :port, :database, :username, :password,
    :replicas_dsns_database, :replicas_dsns_table, :replicas_dsns
  )
  CurrentState = Struct.new(:migrating, :disabled)
  cattr_accessor :state
  cattr_accessor :config

  class << self
    def reset_state_and_configuration
      self.config = Configuration.new
      self.state = CurrentState.new

      self.config.command = lambda { |config, altered_table, alter_argument|
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

    def configure
      yield self
    end

    def command=(new_command)
      self.config.command = new_command
    end

    def replicas_dsns_table(database:, table:, dsns:)
      return ArgumentError.new("database & table must be present") if database.blank? || table.blank?

      self.config.replicas_dsns_database = database
      self.config.replicas_dsns_table = table
      self.config.replicas_dsns = dsns.uniq.map do |dsn|
        parts = dsn.split(",")
        # automatically add default port
        parts << "P=3306" unless parts.any? { |part| part.start_with?("P=") }
        # automatically remove master
        next if parts.include?("h=#{self.config.host}") && parts.include?("P=#{self.config.port}")

        parts.join(",")
      end.compact
    end

    def disable
      self.state.disabled = true
      yield
    ensure
      self.state.disabled = false
    end
  end
end