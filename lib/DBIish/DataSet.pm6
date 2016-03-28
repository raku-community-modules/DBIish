use v6;
unit package DBIish;
use MONKEY-TYPING;

Rakudo::Internals.REGISTER-DYNAMIC: '$*DBDDEFS', {
    PROCESS::<$DBDDEFS> = Hash.new;
};

need DBDish;
class Row does Positional does Associative is export {
    has $!row is required handles <list Array elems Numeric Int AT-POS EXISTS-POS>;
    has $!colmap is required;
    has $.idx;
    has $!pds;

    submethod BUILD(:$!row, :$!colmap, :$!idx) { }

    method AT-KEY(Row:D: $key) {
	$!row[$_] with $!colmap{$key};
    }

    method hash(Row:D:) {
	state % = $!colmap.map: { (.key => $!row[.value]) };
    }

    method keys { self.hash.keys }

    method of {
	Any
    }
    method gist(::?CLASS:D:) {
	self.^name ~ "[$!idx]" ~ $!row.gist;
    }
}

class DataSet does Iterable is export {
    has $!ri;
    has $!colmap;
    has $.current = -1;
    has $.is-empty = False;

    submethod BUILD(:$sth) {
	$!ri = (gather {
	    while $sth._row -> \r { take r; }
	}).iterator;
	$!colmap = Map.new($sth.column-names Z=> (0 ... *));
    }

    method iterator() {
	(gather {
	    my $row;
	    until ($row := $!ri.pull-one) =:= IterationEnd {
		take Row.new(:$row, :$!colmap, :idx(++$!current));
	    }
	    $!is-empty = True;
	}).iterator;
    }

    method Seq() { Seq.new(self.iterator); }

    method list() { List.from-iterator(self.iterator); }
}

augment class Str {
    method SQL(Str:D: DBDish::Connection $dbh = $*DBDDEFS<con>) {
	$dbh.prepare(self);
    }
}
