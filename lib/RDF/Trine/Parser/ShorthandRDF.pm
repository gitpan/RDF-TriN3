# RDF::Trine::Parser::ShorthandRDF
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Trine::Parser::ShorthandRDF - Shorthand RDF Parser

=head1 SYNOPSIS

 use RDF::Trine::Parser;
 my $parser     = RDF::Trine::Parser->new( 'ShorthandRDF' );
 $parser->parse_into_model( $base_uri, $data, $model );

=head1 DESCRIPTION

ShorthandRDF is an extension of N3 syntax. It's currently defined at
L<http://esw.w3.org/ShorthandRDF>.

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
	$VERSION = '0.129';
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
	if ($self->_at_namepattern_test()) {
		$self->_at_namepattern();
	} elsif ($self->_at_dtpattern_test()) {
		$self->_at_dtpattern();
	} elsif ($self->_at_term_test()) {
		$self->_at_term();
	} elsif ($self->_at_pattern_test()) {
		$self->_at_pattern();
	} else {
		$self->SUPER::_directive(@_);
	}
}

sub _at_namepattern_test {
	my $self = shift;
	return $self->__startswith('@namepattern');
}

sub _at_dtpattern_test {
	my $self = shift;
	return $self->__startswith('@dtpattern');
}

sub _at_term_test {
	my $self = shift;
	return $self->__startswith('@term');
}

sub _at_pattern_test {
	my $self = shift;
	return $self->__startswith('@pattern');
}

sub _at_namepattern {
	my $self	= shift;
	
	$self->_eat('@namepattern');
	$self->_ws();
	$self->__consume_ws();
	
	my $pattern = $self->_literal()->literal_value;
	$self->__consume_ws();
	
	my $uri =  $self->_uriref();
	$self->__consume_ws();

	push @{ $self->{shorthands} }, ['@pattern', $pattern, RDF::Trine::Node::Resource->new($uri.'$0')];
	return $self->{shorthands}[-1];
}

sub _at_pattern {
	my $self	= shift;
	
	$self->_eat('@pattern');
	$self->_ws();
	$self->__consume_ws();
	
	my $pattern =  $self->_literal()->literal_value;
	$self->__consume_ws();
	
	my $thing;
	if ($self->_resource_test)
		{ $thing = $self->_resource(); }
	else
		{ $thing = $self->_literal(); }
	$self->__consume_ws();

	push @{ $self->{shorthands} }, ['@pattern', $pattern, $thing];
	return $self->{shorthands}[-1];
}

sub _at_dtpattern {
	my $self	= shift;
	
	$self->_eat('@dtpattern');
	$self->_ws();
	$self->__consume_ws();
	
	my $pattern =  $self->_literal()->literal_value;
	$self->__consume_ws();
	
	my $uri     =  $self->_uriref();
	$self->__consume_ws();

	push @{ $self->{shorthands} }, ['@pattern', $pattern, RDF::Trine::Node::Literal->new('$0', undef, $uri)];
	return $self->{shorthands}[-1];
}

sub _at_term {
	my $self	= shift;
	
	$self->_eat('@term');
	$self->_ws();
	$self->__consume_ws();
	
	my $token;
	
	if ( $self->{'tokens'} =~ m/^([A-Za-z_][A-Za-z0-9_-]*)\s/ )
	{
		$token = $1;
		$self->_eat($token);
	}
	else
	{
		$self->_eat('token_name'); # and die!
	}
	$self->__consume_ws();

	my $thing = $self->_any_node();
	$self->__consume_ws();

	push @{ $self->{shorthands} }, ['@term', $token, $thing];
	return $self->{shorthands}[-1];
}

sub _resource_test {
	my $self	= shift;
	return 0 unless (length($self->{tokens}));
	
	my $rv = $self->SUPER::_resource_test(@_);
	return $rv if $rv;
	
	foreach my $shorthand ( reverse @{ $self->{shorthands} } )
	{
		my ($type, $pattern, $full) = @$shorthand;
		
		if ($type eq '@pattern'
		and $self->{'tokens'} =~ m/^($pattern)\b/)
		{
			return 1;
		}
		elsif ($type eq '@term'
		and (substr $self->{'tokens'}, 0, (length $pattern)) eq $pattern)
		{
			return 1;
		}
	}	

	return 0;
}

sub _resource {
	my $self	= shift;
	
	foreach my $shorthand ( reverse @{ $self->{shorthands} } )
	{
		my ($type, $pattern, $full) = @$shorthand;
		
		if ($type eq '@pattern'
		and $self->{'tokens'} =~ m/^($pattern)\b/)
		{
			my $token = $1;
			$self->_eat($token);
			
			if ($full->is_literal)
			{
				return RDF::Trine::Node::Literal->new(
					$self->_PATTERN_($token, $pattern, $full->literal_value),
					($full->has_language ? $self->_PATTERN_($token, $pattern, $full->literal_value_language) : undef),
					($full->has_datatype ? $self->_PATTERN_($token, $pattern, $full->literal_datatype) : undef),
					);
			}
			elsif ($full->is_resource)
			{
				return RDF::Trine::Node::Resource->new(
					$self->_PATTERN_($token, $pattern, $full->uri),
					);
			}
		}
		elsif ($type eq '@term'
		and (substr $self->{'tokens'}, 0, (length $pattern)) eq $pattern)
		{
			$self->_eat($pattern);
			return $full;
		}
	}	

	return $self->SUPER::_resource(@_);
}

sub _PATTERN_
{
	my ($self, $thingy, $pattern, $template) = @_;

	return unless defined $template;
	$template = "$template";
	return $template unless $template =~ /\$/;

	my %vals = (0 => $thingy);
	my @matches = ($thingy =~ /$pattern/);
	for (my $i=0; $i <= $#matches; $i++)
	{
		$vals{$i + 1} = $matches[$i];
	}
	foreach my $bufname (keys %-)
	{
		$vals{$bufname} = $-{$bufname}->[0];
	}
	
	my $orig_template = $template;
	
	my $rv = '';
	my $count = 0;
	while (length $template)
	{
		$count++;
		die if $count > 300;
		
		if ((substr $template, 0, 1) eq '$')
		{
			$template = substr $template, 1;
			
			my $buffer;
			if ($template =~ /^ \{ ([^\}]+) \} (.*) $/x)
			{
				($buffer, $template) = ($1, $2);
			}
			elsif ($template =~ /^(\d+)/)
			{
				$buffer = $1;
				$template = substr($template, length $buffer);
			}
			elsif ($template =~ /^([_A-Za-z][_A-Za-z0-9]*)/)
			{
				$buffer = $1;
				$template = substr($template, length $buffer);
			}
			else
			{
				throw RDF::Trine::Error::ParserError -text => "Unexpected pattern in replace: ${orig_template}\n";
			}
			$rv .= $vals{$buffer};
		}
		else
		{
			my ($start, $rest) = split /\$/, $template, 2;
			$rv .= $start;
			$template = '$'.(defined $rest ? $rest : '');
		}
	}

	return $rv;
}

1;

__END__

=head1 SEE ALSO

L<RDF::TriN3>,
L<RDF::Trine::Parser::Notation3>.

L<http://esw.w3.org/ShorthandRDF>.

=head1 AUTHOR

Toby Inkster  C<< <tobyink@cpan.org> >>

Based on RDF::Trine::Parser::Turtle by Gregory Todd Williams. 

=head1 COPYRIGHT

Copyright (c) 2006-2010 Gregory Todd Williams. 

Copyright (c) 2010 Toby Inkster.

All rights reserved. This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

=cut
