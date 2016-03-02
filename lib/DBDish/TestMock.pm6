use v6;
need DBDish;

unit class DBDish::TestMock does DBDish::Driver;
need DBDish::TestMock::Connection;

method connect() { DBDish::TestMock::Connection.new(:parent(self)) }
