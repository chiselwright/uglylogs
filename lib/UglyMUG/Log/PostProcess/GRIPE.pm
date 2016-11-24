# vim:ts=4:sw=4:ai:
# $Id: GRIPE.pm,v 1.1.1.1 2002/02/20 12:30:46 chiselwright Exp $

package UglyMUG::Log::PostProcess::GRIPE;

use strict;
use Data::Dumper;

use vars qw { @ISA };
@ISA = qw{ UglyMUG::Log };

# make sure we have a version
use vars qw{ $VERSION };
$VERSION = do{my@r=q$Revision: 1.1.1.1 $=~/\d+/g;sprintf '%d.'.'%02d'x$#r,@r};


=head1 NAME

UglyMUG::Log::Handler::PostProcess::GRIPE

=head1 VERSION

  $Id: GRIPE.pm,v 1.1.1.1 2002/02/20 12:30:46 chiselwright Exp $

=head1 DESCRIPTION

This is a post-processing module for GRIPE entries.
It's used for doing things to the data that aren't related to generating logs.

This allows us to send the data to other places (another file? insert into a database).

If the GRIPE entries go somewhere useful, in the right format, then zeon7 can
do funky web-things with them. Apparently.

=cut

sub new {
	my $proto	= shift;
	my $class	= ref($proto) || $proto;
	my %params	= @_;
	my $self	= { };

	bless ($self, $class);
	$self->dprint(3, "->new()\n");

	# initialise; first from SUPER:: then from ourself
	$self->SUPER::_initialise(\%params);
	$self->_initialise(\%params);

	return $self;
}

sub _initialise() {
	my ($self, $params)	= @_;
	$self->dprint(3, "->_initialise()\n");

	if (defined $params->{'entry'}) {
		$self->{'entry'} = $params->{'entry'};
	}
}


=head2 process($self)

This function demonstrates what can be done with a post-processing
module. (whatever you like really).

In this case we turn it into Tab-Separated-Values and append to a file
in /tmp. Once we have more idea what's required for zeon7 we can do
different (and more useful) things.

=cut
sub process($) {
	my ($self) = @_;

	# split the entry; | is actually $self->{'separator'}{'field'}
	my ($type, $timestamp, @fields) = split(/$self->{'separator'}{'field'}/, $self->{'entry'});

	# open a file to append to
	open (GRIPE, ">>/tmp/gripe.z7") or do {
		warn "can't open /tmp/gripe.z7: $!";
		return undef;
	};

	# print the data tab-separated
	print GRIPE join("\t", $type, $timestamp, @fields), "\n";

	# close the filehandle
	close GRIPE;
}

=head1 COPYRIGHT

This module is Copyright (c) 2002 Chisel Wright.

=head1 LICENCE

This module is released under the terms of the
Artistic Licence.
(http://www.opensource.org/licenses/artistic-license.html)


=head1 AUTHOR

Chisel Wright <chisel@herlpacker.co.uk>, February 2002

=cut

1; # end of module; Do Not Pass Go. Do Not Collect £200.
