use v6;

need DBDish::Role::Connection;
need DBDish::Role::StatementHandle;

=begin pod
=head1 DESCRIPTION
The DBDish module contains generic code that should be re-used by every
database driver, and documentation guidelines for DBD implementation.

It is also an experiment in distributing Pod fragments in and around the
code.  Without syntax highlighting, it is very awkward to work with.  It
shows that this style of file layout is unsuitable for general use.

=head1 ROLES

- See L<DBDish::Role::ErrorHandling>

- See L<DBDish::Role::Connection>

- See L<DBDish::Role::StatementHandle>

=head1 SEE ALSO

The Perl 5 L<DBI::DBD>.

=end pod
