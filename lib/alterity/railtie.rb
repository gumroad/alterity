# frozen_string_literal: true

class Alterity
  class Railtie < Rails::Railtie
    railtie_name :alterity

    rake_tasks do
      namespace :alterity do
        task :intercept_table_alterations do
          Alterity.before_running_migrations
          Rake::Task["alterity:stop_intercepting_table_alterations"].reenable
          ::Mysql2::Client.prepend(Alterity::MysqlClientAdditions)
        end

        task :stop_intercepting_table_alterations do
          Rake::Task["alterity:intercept_table_alterations"].reenable
          Alterity.after_running_migrations
        end
      end

      unless %w[1 true].include?(ENV["DISABLE_ALTERITY"])
        ["migrate", "migrate:up", "migrate:down", "migrate:redo", "rollback"].each do |task|
          Rake::Task["db:#{task}"].enhance(["alterity:intercept_table_alterations"]) do
            Rake::Task["alterity:stop_intercepting_table_alterations"].invoke
          end
        end
      end
    end
  end
end
