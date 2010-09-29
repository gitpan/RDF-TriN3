# RDF::Trine::Node::Formula
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Trine::Node::Formula - RDF Node class for formulae / graph literals

=cut

package RDF::Trine::Node::Formula;

use strict;
use warnings;
no warnings 'redefine';
use base qw(RDF::Trine::Node::Literal);

use RDF::Trine::Error;
use RDF::Trine::Pattern;
use RDF::Trine::Parser::Notation3;
use Scalar::Util qw(blessed);

######################################################################

our ($VERSION);
BEGIN {
	$VERSION	= '0.128';
}

######################################################################

=head1 DESCRIPTION

Formulae are implemented as a subclass of literals. Parts of Trine that have no special
knowledge about formulae (e.g. the Turtle serialiser) will just see them as literals
with a particular datatype URI (http://open.vocab.org/terms/Formula).

If your code needs to detect formulae nodes, try:

  use Scalar::Util qw[blessed];
  if (blessed($node) && $node->isa('RDF::Trine::Node::Formula'))
    { ... do stuff to formulae ... }

or perhaps

  use Scalar::Util qw[blessed];
  if (blessed($node) && $node->can('pattern'))
    { ... do stuff to formulae ... }

=head1 METHODS

=over 4

=cut

=item C<new ( $pattern )>

Returns a new Formula structure. This is a subclass of RDF::Trine::Node::Literal.

$pattern is an RDF::Trine::Pattern or a string capable of being parsed with
RDF::Trine::Parser::Notation3->parse_formula.

=cut

sub new {
	my $class   = shift;
	my $pattern = shift;
	
	if (blessed($pattern) && $pattern->isa('RDF::Trine::Pattern')) {
		return bless [$pattern, undef, undef, undef, undef], $class;
	} else {
		my $p    = RDF::Trine::Parser::Notation3->new;
		my $base = shift;
		my $r    = $p->parse_formula($base, $pattern);
		return $r;
	}
}

sub literal_value {
	my $self	= shift;
	if (@_) {
		$self->from_literal_notation( shift );
	}
	return $self->as_literal_notation;
}

=item C<< pattern ( $node ) >>

Returns the formula as an RDF::Trine::Pattern.

=cut

sub pattern {
	my $self	= shift;
	if (@_) {
		$self->[0] = shift;
	}
	return $self->[0];
}

=item C<< forAll >>

Returns the a list of nodes with the @forAll quantifier.

This is a fairly obscure bit of N3 semantics.

=cut

sub forAll {
	my $self	= shift;
	if (@_) {
		$self->[3] = \@_;
	}
	return unless $self->[3];
	return @{ $self->[3] };
}

=item C<< forSome >>

Returns the a list of nodes with the @forSome quantifier.

This is a fairly obscure bit of N3 semantics.

=cut

sub forSome {
	my $self	= shift;
	if (@_) {
		$self->[4] = \@_;
	}
	return unless $self->[4];
	return @{ $self->[4] };
}

sub literal_value_language {
	return undef;
}

sub literal_datatype {
	return 'http://open.vocab.org/terms/Formula';
}

sub as_ntriples {
	my $self	= shift;
	my $literal	= $self->literal_value;
	my $escaped	= $self->_unicode_escape( $literal );
	$literal	= $escaped;
	if ($self->has_language) {
		my $lang	= $self->literal_value_language;
		return qq("${literal}"\@${lang});
	} elsif ($self->has_datatype) {
		my $dt		= $self->literal_datatype;
		return qq("${literal}"^^<${dt}>);
	} else {
		return qq("${literal}");
	}
}

sub has_language {
	return 0;
}

sub has_datatype {
	return 1;
}

=item C<< as_literal_notation >>

Returns the formula in Notation-3-like syntax, excluding the wrapping "{"..."}".

Uses absolute URIs whenever possible, avoiding relative URI references,
QNames and keywords.

=cut

sub as_literal_notation {
	my $self = shift;
	my $n3   = '';
	
	if ($self->forAll) {
		$n3 .= '@forAll ' . join ', ', map {$_->is_variable?$_->as_string:$_->as_ntriples} $self->forAll;
		$n3 .= " .\n";
	}

	if ($self->forSome) {
		$n3 .= '@forSome ' . join ', ', map {$_->is_variable?$_->as_string:$_->as_ntriples} $self->forSome;
		$n3 .= " .\n";
	}

	foreach my $st ($self->pattern->triples) {
		$n3 .= join ' ', map {$_->is_variable?$_->as_string:$_->as_ntriples} $st->nodes;
		$n3 .= " .\n";
	}
	
	return $n3;
}

=item C<< from_literal_notation ( $string, $base ) >>

Modifies the formula's value using Notation 3 syntax, excluding the wrapping "{"..."}".

=cut

sub from_literal_notation {
	my $self = shift;
	my $new  = __PACKAGE__->new(@_);
	$self->[0] = $new->pattern->clone;
	$self->[3] = [ $new->forAll ];
	$self->[4] = [ $new->forSome ];
	return $self;
}

=item C<< equal ( $node ) >>

Returns true if the two nodes are equal, false otherwise.

TODO - really need a "not equal, but equivalent" method.

=cut

sub equal {
	my ($a, $b) = @_;
	return 0 unless $b->isa(__PACKAGE__);
	return $a->as_literal_notation eq $b->as_literal_notation;
}

sub _compare {
	my ($a, $b) = @_;
	return 1 unless $b->isa(__PACKAGE__);
	return (scalar $a->pattern->triples) <=> (scalar $b->pattern->triples);
}

1;

__END__

=back

=head1 AUTHOR

Toby Inkster  C<< <tobyink@cpan.org> >>

Based on RDF::Trine::Node::Literal by Gregory Todd Williams. 

=head1 COPYRIGHT

Copyright (c) 2006-2010 Gregory Todd Williams. 

Copyright (c) 2010 Toby Inkster.

All rights reserved. This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

=cut
