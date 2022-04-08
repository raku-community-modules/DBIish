use v6;
need DBDish::ErrorHandling;
use DBDish::mysql::Native;

package X::DBDish {
    class DBError::mysql is X::DBDish::DBError {
        has $.sqlstate is required;
    }
}
