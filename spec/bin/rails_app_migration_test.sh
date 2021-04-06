#!/usr/bin/env bash

set -euox pipefail

unset BUNDLE_GEMFILE # because we're going to create a new rails app here and use bundler

sudo apt install percona-toolkit

# Fixes: `Cannot connect to MySQL: Cannot get MySQL var character_set_server: DBD::mysql::db selectrow_array failed: Table 'performance_schema.session_variables' doesn't exist [for Statement "SHOW VARIABLES LIKE 'character_set_server'"] at /usr/local/Cellar/percona-toolkit/3.3.0/libexec/bin/pt-online-schema-change line 2415.`
mysql -h $MYSQL_HOST -u $MYSQL_USERNAME -e 'set @@global.show_compatibility_56=ON'

gem install rails -v $RAILS_VERSION

rails new testapp \
  --skip-action-mailer \
  --skip-action-mailbox \
  --skip-action-text \
  --skip-active-job \
  --skip-active-storage \
  --skip-puma \
  --skip-action-cable \
  --skip-sprockets \
  --skip-spring \
  --skip-listen--skip-javascript \
  --skip-turbolinks \
  --skip-jbuilder--skip-test \
  --skip-system-test \
  --skip-bootsnap \
  --skip-javascript \
  --skip-webpack-install

cd testapp

# Sanity check:
# echo 'gem "mysql2"' >> Gemfile

echo 'gem "alterity", path: "../"' >> Gemfile

bundle

# Local machine test
# echo 'development:
#   adapter: mysql2
#   database: alterity_test' > config/database.yml
# bundle e rails db:drop db:create

echo 'development:
  adapter: mysql2
  database: <%= ENV.fetch("MYSQL_DATABASE") %>
  host: <%= ENV.fetch("MYSQL_HOST") %>
  username: <%= ENV.fetch("MYSQL_USERNAME") %>' > config/database.yml

bundle e rails g model shirt

bundle e rails g migration add_color_to_shirts color:string

# Test default configuration works as expected
bundle e rails db:migrate --trace
bundle e rails runner 'Shirt.columns.map(&:name).include?("color") || exit(1)'

# Now test custom command and replication setup
cp ../spec/bin/custom_config.rb config/initializers/alterity.rb

bundle e rails g migration add_color2_to_shirts color2:string

bundle e rails db:migrate --trace

ruby ../spec/bin/test_custom_config_result.rb

# Also testing what's in replicas_dsns, also checking that master was detected and removed.
bundle e rails runner 'res=ActiveRecord::Base.connection.execute("select dsn from percona.replicas_dsns").to_a.flatten;p(res); res == ["h=host1,P=3306", "h=host2,P=3306"] || exit(1)'
