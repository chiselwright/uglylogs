# vim:ts=4:sw=4:ai:
# $Id: Log.pm,v 1.2 2002/03/07 16:09:19 chiselwright Exp $

package UglyMUG::Log;
use strict;

use Data::Dumper;
use UglyMUG::Log::Email;

# global variables
use vars qw{ $VERSION };

# set version using cvs information
$VERSION = do{my@r=q$Revision: 1.2 $=~/\d+/g;sprintf '%d.'.'%02d'x$#r,@r};

=head1 NAME

UglyMUG::Log - functions for processing logs

=head1 VERSION

  $Id: Log.pm,v 1.2 2002/03/07 16:09:19 chiselwright Exp $

=head1 DESCRIPTION

It's time to do something with the output from the game. You know you should.
But what? How?  This is where UglyMUG::Log steps in. It's the main module for
processing a log-file from UglyMUG (I suspect it can be warped to process most
logfiles, but I haven't written it for that).

It has a function to process logs produced by UglyCODE version B<tag> or
greater.  If entries in the log conform to the expected format they can be
handed on to specific entry handlers, allowing you to process, for example, a
NOTE entry differently from a BUG.

Any entries which don't have a specific handler will be handled by the default
handler (UglyMUG::Log::Handler::Default).

Any entries which don't conform are currently conform are (currently) printed
to STDOUT. It's expected that these will be passed to
UglyMUG::Log::Handler::Unexpected in the near future.

There is also the ability to post-process entries. B<Not Yet Implemented, but Trivial>

=head1 PUBLIC METHODS

The following methods are public:

=cut

=head2 new( option => value, ... )

Create a new instance of the UglyMUG::Log object.

The following options are recognised:

=over 4

=item * logfile

This is the file that you wish to process

=item * outdir

This is the root directory where the admin/ and player/ directories will be
created, and subsequently where the logfiles will be created.

=item * DEBUG

Defaults to 0 (off), set to a positive integer value to enable debugging.
The higher the value, the more verbose debugging becomes.

=item * email_list

The file containing player names, aliases, emails, and HUH|NOHUH

=item * admin_info

The file containing information about which admin logs certain players
(usually game admin) require.

=back

=cut
sub new {
	my $proto	= shift;
	my $class	= ref($proto) || $proto;
	my %params	= @_;
	my $self	= { };

	bless ($self, $class);
	$self->_initialise(\%params);

	# when we start a new log, we should remove old ones
	# apart from those like allgripes which we keep appending to
	$self->deltree("$self->{'_conf'}{'outdir'}/player");
	$self->deltree("$self->{'_conf'}{'outdir'}/admin/day");
	$self->deltree("$self->{'_conf'}{'outdir'}/admin/keep", 'gz$');
	
	return $self;
}

# initialise the new object
sub _initialise($$) {
	my ($self,$params)	= @_;
	$self->dprint(3, " ->_initialise()\n");

	$self->{'separator'}	= {
		'record_start'	=> '\025',
		'record_end'	=> '\026',
		'field'			=> '\027',
	};
	$self->{'entry'}	= 'UNSET';
	$self->{'_conf'}		= {
		'logfile'			=> undef,		# used by this module
		'outdir'			=> undef,		# used by this module
		'log_headers'		=> undef,		# passed to UglyMUG::Log::Email
		'email_list'		=> undef,		# passed to UglyMUG::Log::Email
		'admin_info'		=> undef,		# passed to UglyMUG::Log::Email
		'log_from_address'	=> undef,

		'test_mail_to'		=> undef,		# see: perldoc UglyMUG::Log::Email
		'test_print_mail'	=> 0,			# see: perldoc UglyMUG::Log::Email

		'DEBUG'				=> 0,
	};

	# loop through $self->{'_conf'}, if we have been passed a parameter with the same name, set it
	foreach my $option (keys %{$self->{'_conf'}}) {
		if (exists $params->{$option}) {
			$self->{'_conf'}{$option} = $params->{$option};
		}
	}

	# see if a filename was passed through
	if (exists $params->{'logfile'}) {
		# does a file exist?
		if (-f $params->{'logfile'}) {
			$self->{'_conf'}{'logfile'} = $params->{'logfile'};
		}
		# does a directory exist?
		elsif (-d $params->{'logfile'}) {
			warn qq[cannot process directories as logfiles];
		}
		# neither a file or directory
		else {
			warn qq[unable to use $params->{'logfile'} as a logfile];
		}
	}

	# see if an outdir was passed through
	if (exists $params->{'outdir'}) {
		# does the directory exist?
		if (-d $params->{'outdir'}) {
			# that's good; we want it to exist
			# we want to be able to write to it too
			if (! -w $params->{'outdir'}) {
				die "output directory: $params->{'outdir'} isn't writable\n";
			}

			# set the outdir
			$self->{'_conf'}{'outdir'} = $params->{'outdir'};
		}
		elsif (-e $params->{'outdir'}) {
			# it's bad if outdir exists, but isn't a directory
			die "output directory: $params->{'outdir'} isn't a directory\n";
		}
	}

	# make sure DEBUG is an integer value
	if ($params->{'DEBUG'} !~ /^[0-9]+$/) {
		warn __PACKAGE__ . ": DEBUG must be a non-negative integer value - debugging set to 0 (ZERO)\n";
		$self->{'_conf'}{'DEBUG'} = 0;
	}

	##
	## create instances of useful objects - don't do this for kiddie classes
	##
	if (ref($self) eq 'UglyMUG::Log') {
		# used for sending player logs
		if (not exists $self->{'_class'}{'log_email'}) {
			# we haven't loaded it yet
			$self->{'_class'}{'log_email'} = UglyMUG::Log::Email->new(
				'log_root'			=> $self->{'_conf'}{'outdir'},
				'log_header_root'	=> $self->{'_conf'}{'log_headers'},
				'email_list'		=> $self->{'_conf'}{'email_list'},
				'admin_info'		=> $self->{'_conf'}{'admin_info'},
				'log_from_address'	=> $self->{'_conf'}{'log_from_address'},

				'test_mail_to'		=> $self->{'_conf'}{'test_mail_to'},
				'test_print_mail'	=> $self->{'_conf'}{'test_print_mail'},
			);
		}

		# used for getting player (email/huh) information
		if (not exists $self->{'_class'}{'player_email'}) {
			# we haven't loaded it yet
			$self->{'_class'}{'player_email'} = UglyMUG::Player::Email->new(
				'list'				=> $self->{'_conf'}{'email_list'},
				'cache'				=> 1,
			);
		}
	}
}

# a debug-print function
sub dprint($$$) {
	my $self	= shift;
	my $level	= shift;
	print "[@{[ref($self)]}] @_"	if ( ($self->{'_conf'}{'DEBUG'}) and ($self->{'_conf'}{'DEBUG'} >= $level) );
}

=head2 parse_logfile($self)

This opens and reads the logfile specified by the logfile
option in your call to UglyMUG::Log->new

Parsed entries that match the expected format for UglyCODE logfiles
are passed on to parse().

Entries which do not match the format are passed to unexpected_entry().

=cut
sub parse_logfile($) {
	my ($self) = @_;
	$self->dprint(3, "->parse_logfile()\n");
	my ($in_entry);

	# try to open the file specified in {_conf}{ logfile}
	if (exists $self->{'_conf'}{'logfile'}) {
		# try to open the file for reading
		if (open(LOG, "<$self->{'_conf'}{'logfile'}")) {
			# we just opened the file; we can't be in an entry
			$in_entry = 0;

			while (<LOG>) {
				chomp;			# kill the newline
				
				# if we aren't in a log entry look for a line starting with RECORD_START
				if (not $in_entry) {
					# try to to match a log entry
					if (/^$self->{'separator'}{'record_start'}(.+)/) {
						$self->dprint(4, "matched start of entry: $1\n");
						# we matched the start of a record
						$in_entry = 1;

						# if our match ends with RECORD_END we have a one line entry
						if ($1 =~ /(.+)$self->{'separator'}{'record_end'}$/) {
							# store the matched entry
							$self->{'entry'} = $1;
							$self->dprint(4, "matched entry: $self->{'entry'}\n");
							$in_entry = 0;
						}

						# otherwise it's a multiline entry
						# just store it, so we can append the rest of the entry
						# as we read it
						else {
							$self->{'entry'} = $1;
						}
					}

					# we didn't match RECORD_START; this doesn't conform
					# to the new log format; pass it on to somethhing that
					# can choose what to do - we might like to try to parse
					# old-style logs here
					else {
						if (/^$/) {
							$self->dprint(2, "unexpected entry: [EMPTY LINE]\n");
						}
						else {
							$self->dprint(2, "unexpected entry: $_\n");
						}
						$self->unexpected_entry($_);
					}
				}

				# otherwise we are looking for RECORD_END, the end of a record
				else {
					if (/(.+)$self->{'separator'}{'record_end'}$/) {
						# we have found the end of the record
						$self->{'entry'} .= "\n$1";
						$self->dprint(2, "completed entry: $self->{'entry'}\n");
						$in_entry = 0;
					}
					else {
						# we're still matching a multi-line
						$self->{'entry'} .= "\n$_";
						$self->dprint(4, "MULTI-LINE: $self->{'entry'}\n");
					}
				}

				# if we are not in an entry then we can try
				# to parse the entry that we have read
				if (not $in_entry and defined $self->{'entry'}) {
					$self->dprint(2, "entry: $self->{'entry'}\n");
					$self->parse($self->{'entry'});
				}
			}
		}
		else {
			warn "unable to open '$self->{'_conf'}{'logfile'}' for reading: $!\n";
		}
	}
}

# deal with entries that don't match the new format
sub unexpected_entry($$) {
	my ($self, $entry) = @_;
	 my ($type, $handler);

	# debugging message
	$self->dprint(1, "boy did we not expect to see: $entry\n");

	# try to use UglyMUG::Log::Handler::Unexpected
	$type = 'Unexpected';
	$handler = "UglyMUG::Log::Handler::$type";
	
	# try to use the handler
	if ($self->_require($handler)) {
		# yes; we have successfully 'require'd the handler for unexpected entries
		# either create or update the handler
		$self->_create_or_update_handler($type, $entry);

		# if the handler has the process method - use it
		if ($self->{'_handler'}{"$type"}->can('process')) {
			$self->dprint(4, "$handler->process()\n");
			$self->{'_handler'}{"$type"}->process;
		}

		# otherwise - the handler is crap; it has missing methods
		else {
			$self->dprint(1, "$handler->process DOES NOT exist!! This is not good!!\n");
			warn "$handler->process DOES NOT exist!! This is not good!!\n";
		}
	}

	# otherwise we failed to load the handler
	else {
		warn "unexpected entry: unable to load $handler: entry = $entry\n";
	}
}

=head2 parse($self, $entry)

An entry should be of the form "<type><separator><information>".

The first this parse() does is try to load a handler for <type>
(UglyMUG::Log::Handler::<type> - case sensitive).
If the module exists and contains a process() method then the
entry is passed on to the type-specific handler to be processed.

If process() does not exist then we B<IGNORE> the entry. We also
print a warning to stderr so that the module author can fix it. :)

If the module cannot be loaded then UglyMUG::Log::Handler::DEFAULT
is tried. Again we fail if the module does not have a process()
method.

If we (try and) fail to use process() in the default handler, then
the module die()s with an appropriate message - there should B<always>
be a process() in the default handler, and its absence means something
is seriously wrong.

=cut
sub parse ($$) {
	my ($self, $entry) = @_;
	chomp $entry;
	$self->dprint(4, "->parse(): $entry\n");

	# split <type><separator><rest of line> to get the
	# log type
	if ($entry =~ /^(.+?)$self->{'separator'}{'field'}(.+)$/s) {
		my ($type, $splitentry) = ($1, $2);

		$self->dprint(4, "->parse: entry type: $type\n");

		# do we have a specific handler for this module?
		my $handler = "UglyMUG::Log::Handler::$type";

		if ($self->_require($handler)) {
			# yes; we have successfully 'require'd a specific handler
			$self->dprint(2, "specific handler will be used for $entry\n");

			# either create or update the handler
			$self->_create_or_update_handler($type, $splitentry);
		}
		else {
			# no; we failed to load a type specific handler.
			# use the DEFAULT handler
			$self->dprint(2, "use DEFAULT handler for $entry\n");

			# set the type manually, and update the handler
			$type = 'DEFAULT';
			my $handler = "UglyMUG::Log::Handler::$type";

			# make sure we 'require' the module
			if ($self->_require($handler)) {
				$self->dprint(2, "loaded module $handler\n");
				# either create or update the handler - use the FULL entry
				# the default handler might want to use the information
				$self->_create_or_update_handler($type, $entry);
			}
			else {
				die "failed to load $handler";
			}
		}

		# if $self->{'_handler'}{"$type"} is undefined
		# we failed to load a type-specific handler *and* also
		# failed to load the DEFAULT handler
		if (not defined $self->{'_handler'}{"$type"}) {
			die "failed to load *any* handlers";
		}

		# if the handler has the process method - use it
		if ($self->{'_handler'}{"$type"}->can('process')) {
			$self->dprint(4, "$handler->process()\n");
			$self->{'_handler'}{"$type"}->process;

			# try to post-process the data
			$self->_post_process($type, $splitentry);
		}

		# otherwise - the handler is crap; it has missing methods
		else {
			$self->dprint(1, "$handler->process DOES NOT exist!! This is not good!!\n");
			warn "$handler->process DOES NOT exist!! This is not good!!\n";
		}
	}
	else {
		$self->dprint(1, "couldn't match: $entry\n");
	}
}

=head2 find_admin_logs($self, $rootdir)

This function take a directory, and finds logfiles that exist in
E<lt>rootdirE<gt>/keep and E<lt>rootdirE<gt>/day

The files it finds are returned in a hash-reference which takes the form:

  $result = {
    'keep' => [k_file1, k_file2, ...],
    'day'  => [d_file1, d_file2, ...],
  }

These results can then be used to send admin logs.

=cut
sub find_admin_logs($$) {
	my ($self, $root) = @_;
	my ($result);

	# <root>/admin/keep
	if (! -d "$root/admin/keep") {
		warn "$root/admin/keep is not a directory\n";
		$result->{'keep'} = undef;
	}
	else {
		# get all the files in the directory
		my $files = _list_dir("$root/admin/keep");
		$result->{'keep'} = $files;
	}


	# <root>/admin/day
	if (! -d "$root/admin/day") {
		warn "$root/admin/day is not a directory\n";
		$result->{'day'} = undef;
	}
	else {
		# get all the files in the directory
		my $files = _list_dir("$root/admin/day");
		$result->{'day'} = $files;
	}

	return $result;
}

=head2 find_player_logs($self, $rootdir)

This function looks in each directory in <rootdir> for player specific
logfiles. The files found are returned in an array-reference of the form:

  $results = [
    [ $playerid1, $log1, $log2, ... ],
    [ $playerid1, $log1, $log2, ... ],
    ...
  ]

i.e. each element in the returned list is a list where the first elephant is
the player id, and all elements following that are the names of logfiles which
can (should) be sent to the player.

=cut
sub find_player_logs($$) {
	my ($self, $root) = @_;
	my (@playerdirs, $id, $result);

	# make sure $root is a directory
	if (! -d $root) {
		warn "$root is not a directory\n";
		return undef;
	}
	
	# make sure $root/player exists
	if (! -d "$root/player") {
		warn "$root/player is not a directory\n";
		return undef;
	}
	
	# get a list of directories in $root - <root>/player/playerid
	opendir (DIR, "$root/player")
		or do {
			warn "can't open $root/player for reading: $!";
			return undef;
		};
	# read directories from the directory, ignoring . and ..
	@playerdirs = grep { -d "$root/player/$_" and $_ !~ /^\.\.?/ } readdir(DIR);
	
	# for each directory get a list of files
	foreach $id (@playerdirs) {
		$result->{$id} = _list_dir("$root/player/$id");
	}

	return $result;
}


=head2 send_player_logs($self)

=cut
sub send_player_logs($) {
	my ($self) = @_;
	my ($hash, $playerid, $list);

	# get a hash of lists of logs to send
	$hash = $self->find_player_logs($self->{'_conf'}{'outdir'});

	# run through the hash
	while ( ($playerid, $list) = each %$hash ) {
		# for each log, send it
		for my $log (@$list) {
			$self->{'_class'}{'log_email'}->send_player_log($playerid, $log);
		}
	}
}

=head2 send_admin_logs($self)

=cut
sub send_admin_logs($) {
	my ($self) = @_;
	my ($logs);

	# get the logs that need sending
	$logs = $self->find_admin_logs($self->{'_conf'}{'outdir'});

	# send the day/keep logs
	for my $style ( qw{ day keep } ) {
		# send the logs for $style
		for my $type (@{$logs->{$style}}) {
			$self->{'_class'}{'log_email'}->send_admin_log($style, $type);
		}
	}
}

=head2 TimeString($self, $seconds)

This function converts seconds since epoch into an ISO-8601 compliant date/time string.
 an ISO-8601 compliant date/time string [YYYY-MM-DD hh:mm:ss].

=cut
sub TimeString ($$) {
	my ($self, $epochtime) = @_;
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($epochtime);
	my $timestr = sprintf "%04d-%02d-%02d %02d:%02d:%02d", $year+1900, $mon+1, $mday, $hour, $min, $sec;
}

=head2 deltree($self, $dir, [, $regexp])

Recursively delete the contents of $dir.
$regexp is intended to be an optional (simple)
regular expression to enable us to remove certain files
in a directory (e.g. remove *.gz from admin/keep)

  $log->deltree('/foo/bar/admin', '*gz$');

=cut
sub deltree($$;) {
	my ($self, $dir, $re) = @_;
	my (@list, $regexp);

	$self->dprint(3, "deltree: $dir\n");

	if (defined $re) {
		$regexp = qr{$re};
	}

	# remove the player directories
	opendir(DIR, "$dir")
		or warn "can't opendir $dir: $!";
	# don't include . or .. !
	@list = grep { $_ !~ /^\.\.?/ } readdir(DIR);

	# process each item in the list
	foreach my $thing (@list) {
		if ( -f "$dir/$thing" ) {
			# it's a file
			if (not defined $regexp or $thing =~ $regexp) {
				$self->dprint(3, "removing file: $dir/$thing\n");
				unlink "$dir/$thing"
					or warn "couldn't unlink $dir/$thing: $!";
			}
		}
		elsif ( -d "$dir/$thing" ) {
			$self->dprint(3, "recursing directory: $dir/$thing/\n");
			$self->deltree("$dir/$thing");

			$self->dprint(3, "removing directory:  $dir/$thing/\n");
			rmdir "$dir/$thing"
				or warn "couldn't rmdir $dir/$thing: $!";
		}
	}
}

=head2 make_player_log_dir($self, $playerid)

This function creates a directory for player logs.
It is created as E<lt>outdirE<gt>/player/E<lt>playeridE<gt>.

=cut
sub make_player_log_dir ($$) {
	my ($self, $playerid) = @_;

	return if ( -d "$self->{'_conf'}{'outdir'}/player/$playerid" );

	# is $self->{'conf'}{'outdir'} defined?
	# if so we know it exists, because we checked in _initialise()
	if (! exists $self->{'_conf'}{'outdir'}) {
		die "$self->{'_conf'}{'outdir'} doesn't exist. this top level directory should exist!";
	}

	# make sure we have <outdir>/player
	if (! -e "$self->{'_conf'}{'outdir'}/player") {
		mkdir "$self->{'_conf'}{'outdir'}/player", 0755
			or die "could not create $self->{'conf'}{'outdir'}/player/: $!";
	}

	# make sure <outdir>/player is a directory
	if (-e "$self->{'_conf'}{'outdir'}/player" and ! -d "$self->{'_conf'}{'outdir'}/player" ) {
		die "$self->{'_conf'}{'outdir'}/player is not a directory!";
	}

	# and create <outdir>/player/<id>
	if (! -e "$self->{'_conf'}{'outdir'}/player/$playerid" ) {
		mkdir "$self->{'_conf'}{'outdir'}/player/$playerid", 0755
			or die "could not create $self->{'_conf'}{'outdir'}/player/$playerid/: $!";
	}
}

=head2 make_admin_log_dir($self)

This function creates E<lt>outdirE<gt>/admin, E<lt>outdirE<gt>/admin/day and E<lt>outdirE<gt>/admin/keep
if they don't already exist.

=cut
sub make_admin_log_dir($) {
	my ($self) = shift;

	# is $self->{'conf'}{'outdir'} defined?
	# if so we know it exists, because we checked in _initialise()
	if (! exists $self->{'_conf'}{'outdir'}) {
		die "$self->{'_conf'}{'outdir'} doesn't exist. this top level directory should exist!";
	}

	# make sure we have <outdir>/admin
	if (! -e "$self->{'_conf'}{'outdir'}/admin") {
		mkdir "$self->{'_conf'}{'outdir'}/admin", 0755
			or die "could not create $self->{'conf'}{'outdir'}/admin/: $!";
	}
	
	# now make two subdirectories: day, keep/
	# we use day/ for the logs we send each day, and overwrite with each run
	# we use keep/ for the logs (allgripes) that we append to and don't overwrite each day
	if (-d "$self->{'_conf'}{'outdir'}/admin" ) {
		# the admin/ dir exists - which it should

		# if day/ doesn't exist - make it
		if (! -e "$self->{'_conf'}{'outdir'}/admin/day" ) {
			# go ahead and make day/
			mkdir "$self->{'_conf'}{'outdir'}/admin/day", 0755
				or die "could not create $self->{'_conf'}{'outdir'}/admin: $!";
		}

		# if day/ does exist make sure it's a dir
		else {
			if (! -d "$self->{'_conf'}{'outdir'}/admin/day") {
				# it exists but isn't a directory!
				die "not a directory: $self->{'_conf'}{'outdir'}/admin/day";
			}
		}
		

		# if keep/ doesn't exist - make it
		if (! -e "$self->{'_conf'}{'outdir'}/admin/keep" ) {
			# go ahead and make keep/
			mkdir "$self->{'_conf'}{'outdir'}/admin/keep", 0755
				or die "could not create $self->{'_conf'}{'outdir'}/keep $!";
		}

		# if day/ does exist make sure it's a dir
		else {
			if (! -d "$self->{'_conf'}{'outdir'}/admin/keep") {
				# it exists but isn't a directory!
				die "not a directory: $self->{'_conf'}{'outdir'}/admin/keep";
			}
		}
	}
}

=head2 append_player_log($self, $playerid, $logtype)

This function will append the contents of $self->{'log_message'} to the E<lt>logtypeE<gt> file
for the player with ID $playerid. If the E<lt>logtypeE<gt> file does not exist, it is created.

=cut
# append to the log <type> of user <id>
sub append_player_log($$$) {
	my ($self, $playerid, $logtype) = @_;

	# make sure there is a directory for the player logs(s)
	$self->make_player_log_dir($playerid);

	# open a file for appending to
	open (PLAYER_LOG, ">>$self->{'_conf'}{'outdir'}/player/$playerid/$logtype")
		or do {
			warn "can't create player logfile for appending: $self->{'_conf'}{'outdir'}/player/$playerid/$logtype: $!";
			return undef;
		};

	# append the information
	print PLAYER_LOG "$self->{'log_message'}\n"
		or warn "could not append entry to: $self->{'_conf'}{'outdir'}/player/$playerid/$logtype: $!";
	close PLAYER_LOG;
}

=head2 append_admin_log($self, $type, $style)

This function will append the contents of $self->{'log_message'} to the E<lt>styleE<gt>
file in the E<lt>typeE<gt> directory under admin/.

B<style> will be something like gripe, wall, bug, hack, ...
B<type> will be I<day> or I<keep>.

=cut
sub append_admin_log($$$) {
	my ($self, $type, $style) = @_;

	# make sure style is known
	if ($style !~ /^(day|keep)$/) {
		warn "admin log style must be 'day' or 'keep': '$style' is invalid";
		return undef;
	}

	# make sure the admid output directories exist
	$self->make_admin_log_dir;

	# open a file for appending to 
	open (ADMIN_LOG, ">>$self->{'_conf'}{'outdir'}/admin/$style/$type")
		or do {
			warn "can't create admin logfile for appending: $self->{'_conf'}{'outdir'}/admin/$style/$type: $!";
			return undef;
		};

	# append the information
	print ADMIN_LOG "$self->{'log_message'}\n"
		or warn "could not append entry to: $self->{'_conf'}{'outdir'}/admin/$style/$type: $!";
	close ADMIN_LOG;
}

=head1 FUNCTIONS FOR THE KIDDIES

These functions are primarily intended to be inherited/used
in UglyMUG::Log::Handler::* modules.

There's nothing wrong with using them in other places, after
all they are public methods

=head2 entry($self, $entry)

$handler-E<gt>entry is called when a call to a handler is about to be made
but we have already created an instance of the object - we need to change
the entry that the handler is processing.

=cut
sub entry($$) {
	my ($self, $entry) = @_;
	$self->{'entry'} = $entry;
}

=head1 PRIVATE METHODS

These methods are B<PRIVATE> to this module. Calling them from elsewhere means
you are doing something wrong!

=cut

=head2 _require($self, $module)

This function tries to (dynamically) load $module.
It's (mostly) used to load UglyMUG::Log::Handler::* as we
need them.

This function B<does not> create a new instance of the module,
it will simply return true (1) or false(0, undef) depending on
whether it is able to load the module.

If the load fails because the module doesn't exist, then 0 is returned,
and error mesages are suppressed (unless DEBUG => 1 for UglyMUG::Log).

Any other error is printed to stderr, and undef is returned.

=cut
sub _require($$) {
	my ($self, $req) = @_;
	$self->dprint(3, " ->_require(): $req\n");

	$self->dprint(4, qq[eval "require $req";\n]);
	eval "require $req";
	if ($@) {
		my $err = $@;
		# we can be quiet if we just failed to load a handler
		# it's to be expected
		if ($err =~ /Can't locate .+?.pm./) {
			$self->dprint(1, "no specific handler for $req\n");
			return 0;		# 0 is failure
		}
		else {
			# failed to 'require' the module; report and return unexpected failure
			warn "fatal error: $err";
			return undef;	# undef is fatal error
		}
	}

	$self->dprint(4, "$req successfully 'require'd\n");
	# module 'require'd
	return 1;
}

=head2 _post_process($self, $type, $splitentry)

This function checks for the existance of UglyMUG::Log::PostProcess::$type.
If that exists it tries to call process() in that module.

If the module doesn't exist then we just carry on with everything else.

If the module does exist, but doesn't have the process() function we
print an error to STDERR. I'm not going to worry about I<someone else>
not getting a copy of my data because they can't write modules properly! :-)

=cut
sub _post_process($$$) {
	my ($self, $type, $splitentry) = @_;
	my ($pp);

	# set the name of the module we will try to load
	$pp = "UglyMUG::Log::PostProcess::$type";

	# try to use the post_processor
	if ($self->_require($pp)) {
		# yes; we have successfully 'require'd the post_processor for unexpected entries
		# either create or update the handler
		$self->_create_or_update_post_processor($type, $splitentry);

		# if the handler has the process method - use it
		if ($self->{'_post_processor'}{"$type"}->can('process')) {
			$self->dprint(4, "$pp->process()\n");
			$self->{'_post_processor'}{"$type"}->process;
		}

		# otherwise - the handler is crap; it has missing methods
		else {
			$self->dprint(1, "$pp->process DOES NOT exist!! This is not good!!\n");
			warn "$pp->process DOES NOT exist!! This is not good!!\n";
		}
	}
}
	
=head2 _create_or_update_postprocessor($self, $type, $entry)

This function is used when a post_processor is required.
We don't want to load each post_processor everytime there's an entry that requires
it.
We just need to load it once, and for subsequent uses we just update the
I<entry> that it works with.

  # we want to use the GRIPE post_processor
  $self->_create_or_update_post_processor('GRIPE', $log_entry);
  # now we can use the process() method for the handler
  $self->{'_handler'}{'GRIPE'}->process($type, $splitentry);

=cut
sub _create_or_update_post_processor($$$) {
	my ($self, $type, $entry) = @_;
	$self->dprint(2, "_create_or_update_handler($type, $entry)\n");
	my $pp = "UglyMUG::Log::PostProcess::$type";

	if (exists $self->{'_post_processor'}{"$type"} and defined $self->{'_post_processor'}{"$type"}) {
		# we have already created an instance of $pp
		if ($self->{'_post_processor'}{"$type"}->can('entry')) {
			# the post_processor has an entry() method (which it should since it's
			# inherited from this module
			$self->dprint(4, "$pp->entry(...)\n");
			$self->{'_post_processor'}{"$type"}->entry($entry);
		}

		# otherwise - the post_processor is crap; it has missing methods
		else {
			$self->dprint(1, "$pp->entry does not exist!! This is not good!!\n");
			die "$pp->entry does not exist!! This is not good!!";
		}
	}

	# else: create a new instance of the post_processor
	else {
		$self->dprint(2, "create new instance of $pp\n");
		$self->{'_post_processor'}{"$type"} = $pp->new(
			'entry'		=> $entry,		# the entry without the log type
			%{ $self->{'_conf'} },		# all the configuration options set currently
		);
	}
}

=head2 _create_or_update_handler($self, $type, $entry)

This function is used when a handler is required.
We don't want to load each handler everytime there's an entry that requires
it.
We just need to load it once, and for subsequent uses we just update the
I<entry> that it works with.

  # we want to use the default handler
  $self->_create_or_update_handler('DEFAULT', $log_entry);
  # now we can use the process() method for the handler
  $self->{'_handler'}{'DEFAULT'}->process;

=cut
sub _create_or_update_handler($$$) {
	my ($self, $type, $entry) = @_;
	$self->dprint(2, "_create_or_update_handler($type, $entry)\n");
	my $handler = "UglyMUG::Log::Handler::$type";

	if (exists $self->{'_handler'}{"$type"} and defined $self->{'_handler'}{"$type"}) {
		# we have already created an instance of $handler
		if ($self->{'_handler'}{"$type"}->can('entry')) {
			# the handler has an entry() method (which it should since it's
			# inherited from this module
			$self->dprint(4, "$handler->entry(...)\n");
			$self->{'_handler'}{"$type"}->entry($entry);
		}

		# otherwise - the handler is crap; it has missing methods
		else {
			$self->dprint(1, "$handler->entry does not exist!! This is not good!!\n");
			die "$handler->entry does not exist!! This is not good!!";
		}
	}

	# else: create a new instance of the handler
	else {
		$self->dprint(2, "create new instance of $handler\n");
		$self->{'_handler'}{"$type"} = $handler->new(
			'entry'		=> $entry,		# the entry without the log type
			%{ $self->{'_conf'} },		# all the configuration options set currently
		);
	}
}
	
=head2 _list_dir($dir)

Given a directory return an array-reference for a list of the B<files> found
in the directory.

Returns B<undef> for errors.

=cut
sub _list_dir($) {
	my $dir = shift;
	my (@files);

	if (! -d $dir) {
		warn "not a directory: $dir\n";
		return undef;
	}

	opendir(DIR, $dir)
		or do {
			warn "can't open directory $dir for reading: $!";
			return undef;
		};

	@files = grep { -f "$dir/$_" } readdir(DIR);
	closedir(DIR);
	return \@files;
}


=head1 COPYRIGHT

This module is Copyright (c) 2002 Chisel Wright.

=head1 LICENCE

This module is released under the terms of the Artistic Licence.
(http://www.opensource.org/licenses/artistic-license.html)


=head1 AUTHOR

Chisel Wright <chisel@herlpacker.co.uk>, February 2002

=cut

1; # end of module; thanks for calling
