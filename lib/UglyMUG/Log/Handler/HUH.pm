# vim:ts=4:sw=4:ai:
# $Id: HUH.pm,v 1.1.1.1 2002/02/20 12:30:46 chiselwright Exp $

package UglyMUG::Log::Handler::HUH;

use strict;
use Data::Dumper;

# make sure we have a version
use vars qw{ $VERSION };
$VERSION = do{my@r=q$Revision: 1.1.1.1 $=~/\d+/g;sprintf '%d.'.'%02d'x$#r,@r};

use vars qw { @ISA };
@ISA = qw{ UglyMUG::Log };

=head1 NAME

UglyMUG::Log::Handler::HUH

=head1 VERSION

  $Id: HUH.pm,v 1.1.1.1 2002/02/20 12:30:46 chiselwright Exp $

=head1 DESCRIPTION

This is the B<HUH> specific entry handler.
It formats entries to look like

  [TimeStamp] HUH from PlayerName(#id) in LocationName(#id): Command

This is then appended to the B<huh> log in the specific directory for
either the owner of the room (if the room owner is a player), or the
owner of the room owner (if the room owner is an NPC).

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

	# used for getting player (email/huh) information
	# (can we pass a module-reference in the parameters?)
	if (not exists $self->{'_class'}{'player_email'}) {
		# we haven't loaded it yet
		$self->{'_class'}{'player_email'} = UglyMUG::Player::Email->new(
			'list'				=> $self->{'_conf'}{'email_list'},
			'cache'				=> 1,
		);
	}

	$self->dprint(9, "This is what's in " . ref($self) . ":\n" . Dumper($self));
	$self->dprint(9, "These are the parameters passed to _initialise:\n" . Dumper($params));
}

sub process ($) {
	my ($self) = @_;
	$self->dprint(1, "process: $self->{'entry'}\n");

	# split the entry; | is actually $self->{'separator'}{'field'}
	# huh format: timestamp|playerid|playername|locationid|locationname|locationownerid|npcownerid|message
	my (
		$timestamp,
		$playerid,
		$playername,
		$locationid,
		$locationname,
		$locationownerid,
		$npcownerid,
		$command,
		$args) = split(/$self->{'separator'}{'field'}/, $self->{'entry'});

	# make a readable timestamp
	$self->{'timestr'} = $self->TimeString($timestamp);
	# construct a human readable log message
	$self->{'log_message'} = "[$self->{'timestr'}] HUH from $playername(#$playerid) in $locationname(#$locationid): $command $args";
	# maybe some debug information
	$self->dprint(5, "HUH: $self->{'log_message'}\n");

	# and append to the huh.log for the player
	#$self->append_player_log($locationownerid, 'huh', $self->{'log_message'});
	# if the room owner is an NPC send the HUH to the owner of the NPC
	if ($npcownerid < 0) {
		# a player - send if not NOHUHLOGS
		if ($self->{'_class'}{'player_email'}->requires_huh($locationownerid)) {
			$self->append_player_log($locationownerid, 'huh');
		}
	}
	else {
		# an NPC - send if not NOHUHLOGS
		if ($self->{'_class'}{'player_email'}->requires_huh($npcownerid)) {
			$self->append_player_log($npcownerid, 'huh');
		}
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
