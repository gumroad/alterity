# Alterity

Alterity is a small utility that allows Rails app to run MySQL table alterations via [Percona Toolkit's `pt-online-schema-change`](https://www.percona.com/doc/percona-toolkit/3.0/pt-online-schema-change.html) while running migrations.

## Usage

By default, after adding the gem to the Gemfile, there's nothing to do to use it.  
You can run your normal migrations via `rails db:migrate`, and where a table would have been ALTERed directly, `pt-online-schema-change` is invoked instead.  

Example, running a migration with `add_column :users, :full_name, :string` would normally execute `ALTER TABLE users ADD COLUMN full_name VARCHAR(255)`.  
With Alterity, the following will be executed instead: `pt-online-schema-change [config] D=[database],t=users --alter "ADD COLUMN full_name VARCHAR(255)"`.

## How does it work internally?

**Alterity** is designed for stability, simplicity and flexibility.

Other gems, like [Departure](https://github.com/departurerb/departure), are reliant on many private internal Rails methods.
This creates a recurrent issue where the gem would break migrations every time one of those Rails methods changed behavior or signature, which can happen with any Rails update.  

Only when running a migration, **Alterity** hooks into [one stable, public method of the `mysql2` gem](https://github.com/brianmario/mysql2/blob/b439a895ef6b289e1bc5e07303fc3952713fb948/lib/mysql2/client.rb#L129), where all SQL queries end up.
If the query that's about to be sent to the MySQL server is detected to be a table alteration (`ALTER TABLE`, `CREATE INDEX`, ...), it's sent to be run via `pt-online-schema-change` instead.
That's it.

## Installation

1. You need to have `pt-online-schema-change` installed wherever you intend on running the migrations.

2. Add the gem to your `Gemfile` and `bundle install`:  

```ruby
gem "alterity"
```

## Optional configuration

1- You can configure the behavior in a `config/initializers/alterity.rb` file.

```ruby
Alterity.configure do |config|

  # You can fully customize the command that's will be executed, for example:
  config.command = -> (altered_table, alter_argument) {
    <<~SHELL.squish
    pt-online-schema-change
      -h #{config.host}
      -P #{config.port}
      -u #{config.username}
      --password=#{config.password}
      --alter-foreign-keys-method=auto
      --nocheck-replication-filters
      --critical-load Threads_running=1000
      --max-load Threads_running=200
      --set-vars lock_wait_timeout=1
      --recursion-method 'dsn=D=#{config.replicas_dsns_database},t=#{config.replicas_dsns_table}'
      --execute
      --no-check-alter
      D=#{config.database},t=#{altered_table}
      --alter #{alter_argument}
    SHELL
  }
  # Check out lib/alterity/default_configuration.rb to see the default command used.

  # This option, deactivated by default, will set up a database & table
  # and fill them with the listed DSNs before running migrations.
  # This is useful for PT-OSC (parameter `--recursion-method`) to monitor
  # the replica lag while copying rows.
  # This table will be truncated and re-filled every time you run migrations.
  # See the method `prepare_replicas_dsns_table` in lib/alterity/alterity.rb for details.
  config.replicas(
    database: "percona",
    table: "replicas_dsns",
    dsns: [
      "h=#{ENV["DB_REPLICA1_HOST"]}",
      "h=#{ENV["DB_REPLICA2_HOST"]}",
    ]
  )
end
```

2- You can disable Alterity for a block:

```ruby
Alterity.disable do
  add_column :users, :full_name, :string
end
```

3- You can disable Alterity altogether by setting the environment variable `DISABLE_ALTERITY=1`.


## Requirements / Dependencies

- Ruby >= 2.7  
- Gem: Rails >= 6.1 (to be able to get the main database config via ActiveRecord, and enhance the migration Rake tasks via Railtie)
- Gem: `mysql2` >= 0.3  

## License

Copyright (c) 2021 Christophe Maximin. This software is released under the [MIT License](LICENSE.txt).
