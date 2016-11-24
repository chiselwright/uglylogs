# vim:ts=4:sw=4:ai:
# $Id: Admin.pm,v 1.2 2002/03/15 11:39:20 chiselwright Exp $

package UglyMUG::Log::Admin;
use strict;

use Data::Dumper;
use Storable;

# make sure we have a version
use vars qw{ $VERSION };
$VERSION = do{my@r=q$Revision: 1.2 $=~/\d+/g;sprintf '%d.'.'%02d'x$#r,@r};

# for email lookup
use UglyMUG::Player::Email;

=head1 NAME

UglyMUG::Log::Admin - admin related function for logging

=head1 VERSION

  $Id: Admin.pm,v 1.2 2002/03/15 11:39:20 chiselwright Exp $

=head1 DESCRIPTION

This module has been written to set and retrieve information about
which logs a game administrator would like to receive.

=cut

=head1 PUBLIC METHODS

The following methods are public, and should be used
wherever you get the urge....

=cut

=head2 new( option => value, ... )

Create a new instance of the admin log object

  $logadmin = UglyMUG::Log::Admin->new();

=over 4

The following options are recognised:

=item admin_info

the file that is used to read the admin information from

=item email_list

the file containing player email address information
(I<email.list>). This value is passed through to
UglyMUG::Player::Email.

=item auto_write

setting this to a value that perl evaluates to true
will cause the module to write to the file specified
in the admin_info option each time information about a
player is changed. If this value is false you will
need to manually call store_data() to save any
changes.

=item create_new

setting this to true will cause the module to create
the file given in admin_info. This means you can
create new (and empty) information files.

It will not create directories.

=back

=cut
sub new {
	my $proto	= shift;
	my $class	= ref($proto) || $proto;
	my %params	= @_;
	my $self	= { };

	bless ($self, $class);
	$self->_initialise(\%params);

	return $self;
}

sub _initialise($$) {
	my ($self, $params) = @_;
	
	# set some default values
	$self->{'_conf'} = {
		'admin_info'		=> undef,	# admin log recipient details
		'email_list'		=> undef,	# player information
		'auto_write'		=> 0,		# off
		'create_new'		=> 0,		# create the admin_info file if it doesn't exist
	};

	# default settings for new players
	$self->{'_conf'}{'default_logs'} = {
		'allgripes'		=> 1,
		'boot'			=> 1,
		'bug'			=> 1,
		'command'		=> 1,
		'connect'		=> 1,
		'debug'			=> 1,
		'default'		=> 1,
		'dump'			=> 1,
		'general'		=> 1,
		'gripe'			=> 1,
		'hack'			=> 1,
		'shutdown'		=> 1,
		'wall'			=> 1,
	};

	# if we don't have a datafile, then set it to /tmp/admin.loginfo
	if (exists $params->{'admin_info'}) {
		# does the specified file really exist?
		if (-f $params->{'admin_info'}) {
			$self->{'_conf'}{'admin_info'} = $params->{'admin_info'};
		}
		else {
			if (exists $params->{'create_new'} && $params->{'create_new'}) {
				# try to create the admin_info file
				$self->{'admin'} = {};
				store $self->{'admin'}, $params->{'admin_info'}
					or die "could not save information to $self->{'_conf'}{'admin_info'}: $!\n";
				$self->{'_conf'}{'admin_info'} = $params->{'admin_info'};
			}
			else {
				warn qq[file not found $params->{'admin_info'}\n];
				exit;
			}
		}
	}
	else {
		# set a default admin_info
		$self->{'_conf'}{'admin_info'} = '/tmp/admin.admin_info';
		warn "admin_info using default value of '$self->{'_conf'}{'admin_info'}'\n";
	}

	# automatically write file after changes; default OFF
	if (exists $params->{'auto_write'}) {
		$self->{'_conf'}{'auto_write'} = $params->{'auto_write'} ? 1 : 0;
	}

	# the path to the email list
	if (exists $params->{'email_list'}) {
		# does it exist?
		if (-f $params->{'email_list'}) {
			$self->{'_conf'}{'email_list'} = $params->{'email_list'};
		}
		else {
			warn qq[file not found: $params->{'email'}\n];
			exit;
		}
	}

	# create an instance of UglyMUG::Player::Email
	# we shoud probably allow the list to be passed through
	# as a parameter of UglyMUG::Log::Admin->new()
	$self->{'_email'} = UglyMUG::Player::Email->new(
		'list'          => $self->{'_conf'}{'email_list'},
		'cache'			=> 1,
	);

	# read data from the admin_info file
	$self->_read_data;
}

=head2 store_data

Call this if AutoWrite is off, and you want to save
any changes that you have made

=cut
sub store_data($) {
	my ($self) = @_;

	$self->_store_data;
}

=head2 player_list($self)

This function returns a array-reference of players we have information about.

  $players = $log_admin->player_list;
  print(join(', ', @$players));

=cut
sub player_list($) {
	my $self = shift;
	my @players = sort {$a <=> $b} keys(%{$self->{'admin'}});
	return \@players;
}

=head2 valid_log_names($self)

This function returns an array-reference of known/valid fields
which can be set for a player.

=cut
sub valid_log_names($) {
	my ($self) = @_;

	# make array of known logs
	my @header_row = sort keys %{ $self->{'_conf'}{'default_logs'} };

	# return a reference
	return \@header_row;
}


=head2 wants($self, $player, $log)

This function is used to see if a player requires a specific
log.

  if ( $logadmin->wants($playerid, 'hack') ) {
	  # whatever
  }

  Returns:  0|1

=cut
sub wants($$$) {
	my ($self, $player, $log) = @_;

	if (not exists $self->{'admin'}{$player}{$log}) {
		return 0;
	}
	else {
		return $self->{'admin'}{$player}{$log};
	}
}


=head2 wants_log($self, $log)

This function returns an arrayref of player-ids that
want a specific log

  $hack_recipients = $log_admin->wants_log('hack');

  Returns: arrayref

=cut
sub wants_log($$) {
	my ($self, $log) = @_;
	my ($id, $aref);

	# loop the keys of $self->{admin} - which 'luckily'
	# gives us a list of the players we have information for
	foreach $id (sort {$a <=> $b} keys(%{$self->{'admin'}})) {
		if ($self->wants($id, $log)) {
			# add the id to the list
			push @$aref, $id;
		}
	}

	return $aref;
}

=head2 build_recipient_string($self, $recipients)

This function takes an arrayref to an array containing
ids of players and builds a string list of player addresses
of the form
"First Admin <first@bar.com>, Second Admin <second@bar.com>"

  # get a list of recipients, and build a Bcc string
  $hack_recipients = $log_admin->wants_log('hack');
  $bcc = $log_admin->build_recipient_string($hack_recipients);

  Returns: string; suitable for To, Cc, Bcc

=cut
sub build_recipient_string($$) {
	my ($self, $recipients) = @_;
	my (@addresses, $result, $id);

	foreach $id (@$recipients) {
		my $fmt_email = $self->{'_email'}->get_formatted_email_address($id);
		if (not defined $fmt_email) {
			# something went wrong
			warn "could not create email address string for player #$id";
		}
		else {
			# push them onto the list
			push @addresses, $fmt_email;
		}
	}

	# comma-join the results
	$result = join(', ', @addresses);
	return $result;
}

=head2 set_preference($self, $playerid, $log, $wants)

This function modifies whether a player want to receive a
specific log.

  # player #24235 no longer wants bug logs
  $log_admin->set_preference(24235, 'bug', 0);

=cut
sub set_preference($$$$) {
	my ($self, $playerid, $log, $wants) = @_;

	if (not exists $self->{'admin'}{$playerid}) {
		warn "player #$playerid is not in the list of admin to receive logs.\nuse add_player() to add a player to the list\n";
		return undef;
	}
	else {
		# we should check to make sure it's a valid value for $log
		# however, for now, we don't care
		# make sure the value is 0|1
		$self->{'admin'}{$playerid}{$log} = $wants ? 1 : 0;
		$self->_auto_write;
		return 1;
	}
}

=head2 add_player($self, $playerid)

This function adds a player to those that receive admin logs.
It set default values B<TBA> for the logs, and these can later
be modified with set_preference()

  # GOD wants logs
  $log_admin->add_player(1);

B<This information is only commited to file if Auto-Write is on>.
If AutoWrite is off, you will need to B<manually> call store_data().

=cut
sub add_player($$) {
	my ($self, $playerid) = @_;

	if (exists $self->{'admin'}{$playerid}) {
		warn "player #$playerid is already listed!\n";
		return undef;
	}
	else {
		my %settings = %{ $self->{'_conf'}{'default_logs'} };	# get a dereferenced copy of the defaults
		$self->{'admin'}{$playerid} = \%settings;				# and set it for the new player
		$self->_auto_write;
	}
}

=head2 remove_player($self, $playerid)

This function removes a player from the information we store.

  $log_admin->remove_player(1);

B<This information is only commited to file if Auto-Write is on>.
If AutoWrite is off, you will need to B<manually> call store_data().

=cut
sub remove_player($$) {
	my ($self, $playerid) = @_;

	if (exists $self->{'admin'}{$playerid}) {
		# we have an entry for the player - remove it
		delete($self->{'admin'}{$playerid});
		$self->_auto_write;
	}
	else {
		# do nothing
	}
}

=head2 in_list($self, $playerid)

This function returns 1 if the playerid is already in the list
of players we have information for. If the player isn't listed
0 (zero) is returned.

  # only try to add a player if they're not already listed
  if (not $log_admin->in_list($playerid)) {
    $log_admin->add_player($playerid);
  }

=cut
sub in_list($$) {
	my ($self, $playerid) = @_;
	
	if (exists $self->{'admin'}{$playerid}) {
		return 1;
	}
	else {
		return 0;
	}
}

=head2 tsv_dump($self, $outfile)

This function dumps the data about the players
into a file specified by $outfile. It's not really
an essential function, but some people seem to like
these things.

The first row in the file contains column headers,
and not player data.

  # dump the data for all those spreadsheet users :)
  $self->tsv_dump('/tmp/uglyadminlogs.tsv');

=cut
sub tsv_dump($$) {
	my ($self, $outfile) = @_;

	# try to open the outfile
	open (TSV, ">$outfile") or do {
		warn "can't open $outfile for writing: $!\n";
		return;
	};

	# we want to build a file that looks like:
	#   id  | type1 | type2 | ...
	#  $id  |  y/n  |  y/n  | ...
	my (@header_row, $player, @player_row, $header);

	@header_row = sort keys %{ $self->{'_conf'}{'default_logs'} };
	# print the header-row
	print TSV	("playerid\t", join("\t", @header_row), "\n");

	# for each player
	foreach $player (sort {$a <=> $b} keys(%{$self->{'admin'}})) {
		# blank @player_row
		@player_row = ();
		# push y/n onto the row for each log type
		foreach $header (@header_row) {
			push	@player_row,
					( $self->wants($player, $header) ? 'Y' : 'N' );
		}

		# print the row
		print TSV	("$player\t", join("\t", @player_row), "\n");
	}
	
	close TSV;
}

################################################
#              PRIVATE FUNCTIONS               #
################################################ 

=head1 PRIVATE METHODS

These functions are B<PRIVATE> to the module, and
should never be used in any code I<you> write.

If you find yourself accessing these modules outside
this file, please have a word with the author.

=cut

=head2 _read_data

This checks that $self->{'_conf'}{'admin_info'} is a
file. If it is, the Storable::retrieve method is
used to read data about the admin from the specified file.

=cut
sub _read_data($) {
	my ($self) = @_;

	if (! -f $self->{'_conf'}{'admin_info'}) {
		warn "$self->{'_conf'}{'admin_info'}: file not found";
	}
	else {
		$self->{'admin'} = retrieve($self->{'_conf'}{'admin_info'});
	}
}

=head2 _store_data

Try to use Storable::store to save $self->{'admin'} to a
file.

=cut

sub _store_data($) {
	my ($self) = @_;

	store $self->{'admin'}, $self->{'_conf'}{'admin_info'}
		or warn "could not save information to $self->{'_conf'}{'admin_info'}: $!";
}

=head2 _auto_write

This is a PRIVATE method to decide whether to store data or not.
It should be called after changes to $self->{'admin'}, and will
(if required) write $self->{'_conf'}{'admin_info'}.

  $self->{'admin'}{$player}{$log} = 1;
  $self->_auto_write;

=cut
sub _auto_write($) {
	my ($self) = @_;

	if ($self->{'_conf'}{'auto_write'}) {
		$self->_store_data;
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

1; # end of module
