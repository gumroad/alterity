# frozen_string_literal: true

module Alterity
  module MysqlClientAdditions
    def query(sql, options = {})
      return super(sql, options) if Alterity.state.migrating
      Alterity.process_sql_query(sql) { super(sql, options) }
    end
  end
end
