use v6;

use DBDish;

need DBDish::TestMock::Connection;

unit class DBDish::TestMock;

method connect() { DBDish::TestMock::Connection.new }
