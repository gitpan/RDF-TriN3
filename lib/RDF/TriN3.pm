package RDF::TriN3;

use 5.008;
use RDF::Trine;
use RDF::Trine::Node::Formula;
use RDF::Trine::Parser::Notation3;
use RDF::Trine::Serializer::Notation3;

our $VERSION = '0.126';

1;

__END__

=head1 NAME

RDF::TriN3 - notation 3 extensions for RDF::Trine

=head1 DESCRIPTION

This module extends L<RDF::Trine> in three ways:

=over 4

=item * Adds a Notation 3 parser.

=item * Adds a Notation 3 serializer.

=item * Provides a subclass of literals to represent Notation 3 formulae.

=back

=head1 BUGS AND LIMITATIONS

Implementing N3 logic and the cwm built-ins is considered outside the scope
of this module, though I am interested in doing that as part of a separate
project.

RDF::TriN3 currently relies entirely on RDF::Trine to provide implementations
of the concept of graphs, and storage. Thus any graphs that can't be
represented using RDF::Trine can't be represented in RDF::TriN3. RDF::Trine's
graph model is a superset of RDF, but a subset of Notation 3's model. While
this allows literal subjects, and literal and blank node predicates, these
may not be supported by all storage engines; additionally top-level variables
(?foo), and top-level @forSome and @forAll (i.e. not nested inside a formula)
might cause problems.

Please report any bugs to L<http://rt.cpan.org/>.

=head1 SEE ALSO

L<RDF::Trine::Node::Formula>,
L<RDF::Trine::Parser::Notation3>,
L<RDF::Trine::Serializer::Notation3>.

L<RDF::Trine>.

L<http://www.perlrdf.org/>.

=head1 AUTHOR

Toby Inkster E<lt>tobyink@cpan.orgE<gt>.

=head1 COPYRIGHT

Copyright 2010 Toby Inkster

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
