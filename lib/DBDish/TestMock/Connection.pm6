use v6;
need  DBDish;

unit class DBDish::TestMock::Connection does DBDish::Connection;
need DBDish::TestMock::StatementHandle;

method prepare($statement) {
    DBDish::TestMock::StatementHandle.new(:$statement, :parent(self), |%_)
}
method _disconnect { }
