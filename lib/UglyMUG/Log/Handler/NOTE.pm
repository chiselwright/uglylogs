# vim:ts=4:sw=4:ai:
# $Id: NOTE.pm,v 1.1.1.1 2002/02/20 12:30:46 chiselwright Exp $

package UglyMUG::Log::Handler::NOTE;

use strict;
use Data::Dumper;

# make sure we have a version
use vars qw{ $VERSION };
$VERSION = do{my@r=q$Revision: 1.1.1.1 $=~/\d+/g;sprintf '%d.'.'%02d'x$#r,@r};

use vars qw { @ISA };
@ISA = qw{ UglyMUG::Log };

=head1 NAME

UglyMUG::Log::Handler::NOTE

=head1 VERSION

  $Id: NOTE.pm,v 1.1.1.1 2002/02/20 12:30:46 chiselwright Exp $

=head1 DESCRIPTION

This is the B<NOTE> specific entry handler.
It formats entries to look like

  [TimeStamp] Note in RoomName(#id): A Message
  [TimeStamp] [NPC: NPCname(#id)] Note in RoomName(#id): A Message

B<Note> that the RoomID is B<not> shown if the player would not
normally be able to see the ID of the room. This stops players
from, for example, going to the UglyHUB, @note-ing a message
and seeing the ID of the UglyHUB in their next note log.

This is then appended to the B<note> log in the player specific directory.

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

	# split the entry; | is actually $self->{'separator'}{'field'}
	# note format: timestamp|playerid|playername|roomid|roomname|message
	# -- ADD A FIELD TO THE NOTE OUTPUT | show room id | true/ false -- 
	my (
		$timestamp,
		$playerid,
		$playername,
		$roomid,
		$roomname,
		$npcownerid,
		$showroomid,
		$message) = split(/$self->{'separator'}{'field'}/, $self->{'entry'});

	# make a readable timestamp
	$self->{'timestr'} = $self->TimeString($timestamp);

	# construct a human readable log message
	if ($showroomid eq 'showid') {
		# if a player could see the room-id in the game, show them the room ID that they @note'd in
		$roomname = "$roomname (#$roomid)";
	}

	# create entry and append to the note log for the player
	# if the npc-ownerid is -ve then it's a normal player
	if ($npcownerid < 0) {
		# just create a normal note log entry
		$self->{'log_message'} = "[$self->{'timestr'}] Note in $roomname: $message";
		
		# debugging information; if we want it
		$self->dprint(5, "NOTE: player: $playerid: $self->{'log_message'}\n");

		# append to the player's note log
		$self->append_player_log($playerid, 'note', $self->{'log_message'});
	}

	# otherwise the note was made by an NPC and should be sent to it's owner:
	else {
		# put information about the NPC into the entry. 
		$self->{'log_message'} = "[$self->{'timestr'}] [NPC: $playername(#$playerid)] Note in $roomname: $message";

		# debugging information; if we want it
		$self->dprint(5, "NOTE: NPC: $playerid --> $npcownerid: $self->{'log_message'}\n");

		# append to the NPC owner's note log
		$self->append_player_log($npcownerid, 'note');
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
