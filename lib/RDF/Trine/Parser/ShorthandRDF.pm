# RDF::Trine::Parser::ShorthandRDF
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Trine::Parser::ShorthandRDF - Shorthand RDF Parser

=head1 SYNOPSIS

 use RDF::Trine::Parser;
 my $parser     = RDF::Trine::Parser->new( 'ShorthandRDF' );
 $parser->parse_into_model( $base_uri, $data, $model );

=head1 DESCRIPTION

ShorthandRDF is an extension of N3 syntax. It defines a couple of extra "at rules".

=head2 @namepattern

Like C<< @prefix >> this specifies that particular tokens should be expanded through
the addition of a URI prefix. However rather than defining a QName prefix for these
tokens, a regular expression for them is defined.

  @namepattern "\d{1,2}[A-Z][a-z]{2}\d{4}" <http://example.net/days/> .
  
  <#someEvent> <#onDay> 6Apr2008 .
  
Is equivalent to the following Turtle:

  <#someEvent> <#onDay> <http://example.net/days/6Apr2008> .

=head2 @datatype

Similar to C<< @namepattern >>, but produces a datatyped literal instead.

  @datatype "\d{1,2}[A-Z][a-z]{2}\d{4}" <http://example.net/day> .
  
  <#someEvent> <#onDay> 6Apr2008 .

Is equivalent to the following Turtle:

  <#someEvent> <#onDay> "6Apr2008"^^<http://example.net/day> .

=head2 Precedence

In the case of multiple C<< @namepattern >> or C<< @datatype >> definitions that
match the same token, the earlier definition wins.

=head1 METHODS

This package exposes the same methods as RDF::Trine::Parser::Notation3.

=cut

package RDF::Trine::Parser::ShorthandRDF;

use strict;
use warnings;
no warnings 'redefine';
no warnings 'once';
use base qw(RDF::Trine::Parser::Notation3);
use RDF::Trine qw(literal);
use RDF::Trine::Statement;
use RDF::Trine::Namespace;
use RDF::Trine::Node;
use RDF::Trine::Error;
use Scalar::Util qw(blessed looks_like_number);

our ($VERSION, $rdf, $xsd, $logic, $owl);

BEGIN {
	$VERSION = '0.128';
	$RDF::Trine::Parser::parser_names{ 'shorthand-rdf' }  = __PACKAGE__;
	$RDF::Trine::Parser::parser_names{ 'shorthandrdf' }   = __PACKAGE__;
	$RDF::Trine::Parser::parser_names{ 'shorthand' }      = __PACKAGE__;
	my $class = __PACKAGE__;
	$RDF::Trine::Parser::encodings{ $class } = 'utf8';
	foreach my $type (qw(text/x.shorthand-rdf text/x-shorthand-rdf)) {
		$RDF::Trine::Parser::media_types{ $type } = __PACKAGE__;
	}
}

# Force the default prefix to be bound to the base URI.
sub _Document {
	my $self	= shift;
	my $uri = $self->{'baseURI'};
	local($self->{bindings}{''}) = ($uri =~ /#$/ ? $uri : "${uri}#");
	local($self->{'keywords'}) = undef;
	local($self->{'shorthands'}) = [];
	$self->SUPER::_Document(@_);
}

# Shorthand-specific directives
sub _directive {
	my $self	= shift;
	if ($self->_namepattern_test()) {
		$self->_namepattern();
	} elsif ($self->_dtpattern_test()) {
		$self->_dtpattern();
	} else {
		$self->SUPER::_directive(@_);
	}
}

sub _namepattern_test {
	my $self = shift;
	return $self->__startswith('@namepattern');
}

sub _dtpattern_test {
	my $self = shift;
	return $self->__startswith('@datatype');
}

sub _namepattern {
	my $self	= shift;
	
	$self->_eat('@namepattern');
	$self->_ws();
	$self->__consume_ws();
	
	my $pattern =  $self->_literal()->literal_value;
	$self->__consume_ws();
	
	my $uri     =  $self->_uriref();
	$self->__consume_ws();

	push @{ $self->{shorthands} }, ['@namepattern', $pattern, $uri];
	return $self->{shorthands}[-1];
}

sub _dtpattern {
	my $self	= shift;
	
	$self->_eat('@datatype');
	$self->_ws();
	$self->__consume_ws();
	
	my $pattern =  $self->_literal()->literal_value;
	$self->__consume_ws();
	
	my $uri     =  $self->_uriref();
	$self->__consume_ws();

	push @{ $self->{shorthands} }, ['@datatype', $pattern, $uri];
	return $self->{shorthands}[-1];
}

sub _resource_test {
	my $self	= shift;
	return 0 unless (length($self->{tokens}));
	
	my $rv = $self->SUPER::_resource_test(@_);
	return $rv if $rv;
	
	foreach my $shorthand ( @{ $self->{shorthands} } )
	{
		my ($type, $pattern, $uri) = @$shorthand;
		if ( $self->{'tokens'} =~ m/^($pattern)\b/ )
		{
			return 1;
		}
	}	

	return 0;
}

sub _resource {
	my $self	= shift;
	
	foreach my $shorthand ( @{ $self->{shorthands} } )
	{
		my ($type, $pattern, $uri) = @$shorthand;
		if ( $self->{'tokens'} =~ m/^($pattern)\b/ )
		{
			my $token = $1;
			$self->_eat($token);
			
			if ($type eq '@datatype')
			{
				return RDF::Trine::Node::Literal->new($token, undef, $uri);
			}
			elsif ($type eq '@namepattern')
			{
				return $self->__URI($uri.$token, $self->{baseURI});
			}
		}
	}	

	return $self->SUPER::_resource(@_);
}

1;

__END__

=head1 SEE ALSO

L<http://esw.w3.org/ShorthandRDF> .

=head1 AUTHOR

Toby Inkster  C<< <tobyink@cpan.org> >>

Based on RDF::Trine::Parser::Turtle by Gregory Todd Williams. 

=head1 COPYRIGHT

Copyright (c) 2006-2010 Gregory Todd Williams. 

Copyright (c) 2010 Toby Inkster.

All rights reserved. This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

=cut
