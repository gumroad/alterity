# frozen_string_literal: true

class Alterity
  Configuration = Struct.new(
    :command,
    :host, :port, :database, :username, :password,
    :replicas_dsns_database, :replicas_dsns_table, :replicas_dsns,
    :before_command,
    :on_command_output,
    :after_command
  )
  CurrentState = Struct.new(:migrating, :disabled)
  cattr_accessor :state
  cattr_accessor :config

  class << self
    def reset_state_and_configuration
      self.config = Configuration.new
      class << config
        def replicas(database:, table:, dsns:)
          return ArgumentError.new("database & table must be present") if database.blank? || table.blank?

          self.replicas_dsns_database = database
          self.replicas_dsns_table = table
          self.replicas_dsns = dsns.uniq.map do |dsn|
            parts = dsn.split(",")
            # automatically add default port
            parts << "P=3306" unless parts.any? { |part| part.start_with?("P=") }
            parts.join(",")
          end.compact
        end
      end

      self.state = CurrentState.new
      load "#{__dir__}/default_configuration.rb"
    end

    def configure
      yield config
    end

    def disable
      state.disabled = true
      yield
    ensure
      state.disabled = false
    end
  end
end
