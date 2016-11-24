# vim:ts=4:sw=4:ai:
# $Id: HACK.pm,v 1.3 2002/03/14 15:38:56 chiselwright Exp $

package UglyMUG::Log::Handler::HACK;

use strict;
use Data::Dumper;

# make sure we have a version
use vars qw{ $VERSION };
$VERSION = do{my@r=q$Revision: 1.3 $=~/\d+/g;sprintf '%d.'.'%02d'x$#r,@r};

use vars qw { @ISA };
@ISA = qw{ UglyMUG::Log };

=head1 NAME

UglyMUG::Log::Handler::HACK

=head1 VERSION

  $Id: HACK.pm,v 1.3 2002/03/14 15:38:56 chiselwright Exp $

=head1 DESCRIPTION

This is the B<HACK> specific entry handler.
It formats entries to look like

  [TimeStamp] A Message

This is then appended to the B<hack> log in the
B<day> directory under B<admin>.

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
	my (@hack_args, $timestamp, $message, $playerid);

	$self->dprint(1, "process: $self->{'entry'}\n");

	# split the entry; | is actually $self->{'separator'}{'field'};
	# depending on the game version we might have
	#   HACK|timestamp|message
	# or
	#   HACK|timestamp|#who-to-tell|message
	# we'll just work out which one it is by the number of elements in an
	# array after we split at FIELD_SEPARATOR
	@hack_args = split(/$self->{'separator'}{'field'}/, $self->{'entry'});

	if (scalar @hack_args == 2) {
		# timestamp|message
		($timestamp, $message) = @hack_args;
		# undefine $playerid explicitly
		$playerid = undef;
	}
	elsif (scalar @hack_args == 3) {
		# timestamp|playerid|message
		($timestamp, $playerid, $message) = @hack_args;
	}

	# make a readable timestamp
	$self->{'timestr'} = $self->TimeString($timestamp);

	# construct a human readable log message
	$self->{'log_message'} = "[$self->{'timestr'}] $message";

	# maybe some debug information
	$self->dprint(5, "HACK: $self->{'log_message'}\n");

	# and append to the hack log
	$self->append_admin_log('hack', 'day');

	# if we have a playerid, append the hack to the player's own hack log
	if (defined $playerid) {
		$self->append_player_log($playerid, 'hack');
	}
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
