# vim:ts=4:sw=4:ai:
# $Id: Unexpected.pm,v 1.1.1.1 2002/02/20 12:30:46 chiselwright Exp $

package UglyMUG::Log::Handler::Unexpected;

use strict;
use Data::Dumper;

# make sure we have a version
use vars qw{ $VERSION };
$VERSION = do{my@r=q$Revision: 1.1.1.1 $=~/\d+/g;sprintf '%d.'.'%02d'x$#r,@r};

use vars qw { @ISA };
@ISA = qw{ UglyMUG::Log };

=head1 NAME

UglyMUG::Log::Handler::Unexpected

=head1 VERSION

  $Id: Unexpected.pm,v 1.1.1.1 2002/02/20 12:30:46 chiselwright Exp $

=head1 DESCRIPTION

This is the handler for log entries that do not match the new
format for logfiles.

No formatting is attempted on the message.

This is then appended to the B<default> log in the B<day> directory under B<admin>.

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

	$self->dprint(9, "This is what's in " . ref($self) . ":\n" . Dumper($self));
	$self->dprint(9, "These are the parameters passed to _initialise:\n" . Dumper($params));
}

sub process ($) {
	my ($self) = @_;
	$self->dprint(1, "process: $self->{'entry'}\n");

	# set log_message - this is what goes into the file
	$self->{'log_message'} = "UNEXPECTED ENTRY: $self->{'entry'}";

	# maybe some debug information
	$self->dprint(5, "UNEXPECTED ENTRY: $self->{'log_message'}\n");

	# and append to the default log
	$self->append_admin_log('default', 'day');
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

1; # end of module; all change please
