use v6;
need DBDish;

unit class DBDish::TestMock:ver($?DISTRIBUTION.meta<ver>):api($?DISTRIBUTION.meta<api>):auth($?DISTRIBUTION.meta<auth>) does DBDish::Driver;
need DBDish::TestMock::Connection;

method connect() { DBDish::TestMock::Connection.new(:parent(self)) }
method version() { False }
