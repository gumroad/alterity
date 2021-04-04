# frozen_string_literal: true

module Alterity
  class Railtie < Rails::Railtie
    railtie_name :alterity

    rake_tasks do
      namespace :alterity do
        task :intercept_table_alterations do
          Alterity.before_running_migrations
          ::Mysql2::Client.prepend(Alterity::Mysql2Additions)
        end

        task :stop_intercepting_table_alterations do
          Alterity.after_running_migrations
        end
      end
    end

    unless ["1", "true"].include?(ENV["DISABLE_ALTERITY"])
      ["migrate", "migrate:up", "migrate:down", "migrate:redo", "rollback"].each do |task|
        Rake::Task["db:#{task}"].enhance(["alterity:intercept_table_alterations"]) do
          Rake::Task["alterity:stop_intercepting_table_alterations"].invoke
        end
      end
    end
  end
end
