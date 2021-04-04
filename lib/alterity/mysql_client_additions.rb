# frozen_string_literal: true

class Alterity
  module MysqlClientAdditions
    def query(sql, options = {})
      return super(sql, options) unless Alterity.state.migrating

      Alterity.process_sql_query(sql) { super(sql, options) }
    end
  end
end
