use v6;
need  DBDish;

unit class DBDish::TestMock::Connection does DBDish::Connection;
need DBDish::TestMock::StatementHandle;

method prepare($) { DBDish::TestMock::StatementHandle.new }
method disconnect { True }
