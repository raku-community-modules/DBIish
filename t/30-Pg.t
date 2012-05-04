use v6;
use Test;
plan 2;
use DBDish::Pg;

is pg-replace-placeholder(q[INSERT INTO "foo?" VALUES('?', ?, ?)]),
                          q[INSERT INTO "foo?" VALUES('?', $1, $2)],
                         'basic tokenization';

is pg-replace-placeholder(q['a\.b''cd?', "\"?", ?]),
                          q['a\.b''cd?', "\"?", $1],
                        'backslash escapes and doubled single quote';
