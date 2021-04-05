# frozen_string_literal: true

RSpec.describe Alterity do
  describe ".process_sql_query" do
    it "executes command on table altering queries" do
      [
        ["ALTER TABLE `users` ADD `col` VARCHAR(255)", "`users`", "ADD `col` VARCHAR(255)"],
        ["ALTER TABLE `users` ADD `col0` INT(11), DROP `col1`", "`users`", "ADD `col0` INT(11), DROP `col1`"],
        ["CREATE INDEX `idx_users_on_col` ON `users` (col)", "`users`", "ADD INDEX `idx_users_on_col` (col)"],
        ["CREATE UNIQUE INDEX `idx_users_on_col` ON `users` (col)", "`users`", "ADD UNIQUE INDEX `idx_users_on_col` (col)"],
        ["DROP INDEX `idx_users_on_col` ON `users`", "`users`", "DROP INDEX `idx_users_on_col`"],
        ["alter table users drop col", "users", "drop col"],
        ["  ALTER TABLE\n   users\n   DROP col", "users", "DROP col"]
      ].each do |(query, expected_table, expected_updates)|
        puts query.inspect
        expected_block = proc {}
        expect(expected_block).not_to receive(:call)
        expect(Alterity).to receive(:execute_alter).with(expected_table, expected_updates)
        Alterity.process_sql_query(query, &expected_block)
      end
    end

    it "ignores non-altering queries" do
      [
        "select * from users",
        "insert into users values (1)",
        "delete from users",
        "begin",
        "SHOW CREATE TABLE `users`",
        "SHOW TABLE STATUS LIKE `users`",
        "SHOW KEYS FROM `users`",
        "SHOW FULL FIELDS FROM `users`"
      ].each do |query|
        expected_block = proc {}
        expect(expected_block).to receive(:call)
        expect(Alterity).not_to receive(:execute_alter)
        Alterity.process_sql_query(query, &expected_block)
      end
    end
  end
end
