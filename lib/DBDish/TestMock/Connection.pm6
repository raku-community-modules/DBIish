
use v6;

need DBDish::TestMock::StatementHandle;
need DBDish::Role::Connection;

unit class DBDish::TestMock::Connection does DBDish::Role::Connection;

method prepare($) { DBDish::TestMock::StatementHandle.new }
method disconnect { True }
