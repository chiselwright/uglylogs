# vim:ts=4:sw=4:ai:
# $Id: Email.pm,v 1.3 2002/03/14 14:55:33 chiselwright Exp $

package UglyMUG::Log::Email;
use strict;

use Data::Dumper;
use MIME::Lite;					# for sending messages
use Storable;					# for storing/retrieving admin info
use UglyMUG::Player::Email;		# for getting email addresses to send to
use UglyMUG::Log::Admin;		# for building the recipient list for admin logs
use Compress::Zlib;				# for compressing oversized logs

# global variables
use vars qw{ $VERSION };

# set version using cvs information
$VERSION = do{my@r=q$Revision: 1.3 $=~/\d+/g;sprintf '%d.'.'%02d'x$#r,@r};

=head1 NAME

UglyMUG::Log::Email - functions for emailing logs to the relevant people

=head1 VERSION

  $Id: Email.pm,v 1.3 2002/03/14 14:55:33 chiselwright Exp $

=head1 DESCRIPTION

The functions in this module are intended for that uncertain
moment when you realise you've just generated a plethora of
log emails, and are wondering what on earth to do with them

=head1 PUBLIC METHODS

The following methods are public:

=cut

=head2 new( option => value, ... )

Create a new in instance of the log-email object

  $log_email = UglyMUG::Log::Email->new();

=over 4

The following options are recognised:

=item * log_root

The directory which contains admin/ and player/
and all of the files generated from parsing the logfile.

=item * log_header_root

The directory where header and footer files live.
If this isn't specified it's assumed to be
E<lt>log_rootE<gt>/headers

=item * email_list

The file containing player name, alias, email, and HUH|NOHUH information.

=item * log_from_address

This is the address that will be used as the From: address for all outgoing
email messages.

=item * admin_info

The file containing information about the players that receive
I<administrative> logs, and which ones.

=item * gzip_large_logs

This defaults to B<1>. If a log is greater than I<gzip_size> B<bytes>
it will be gzipped and attached to the email instead of being quoted
as the message body.
To turn this off set the value to something that perl evaluates as false.

=item * gzip_size

This is the size (in bytes) that must be exceeded for a file to be
gzipped and attached instead of quoted as the message body.
This option has no effect if I<gzip_large_logs> evaluates to false.

=item * test_mail_to

If this option is set then any of the To/Cc/Bcc fields which are set will be
set to this value, and X-UglyMUG-Recipients: will be set to the original
recipient.

This is useful for making sure the emails get successfully without generating
copious amount of unwanted mail for people that would recieve these in a live
instance

=item * test_print_mail

If this is set to a value that perl evaluates to true (1 is normally a safe bet
:-) then the mail message will be printed to STDOUT instead of being emailed.

This is useful for checking that messages appear to be correctly constructed
without the need to email them anywhere.

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

	# default settings
	$self->{'_conf'} = {
		'log_root'			=> undef,
		'log_header_root'	=> undef,
		'email_list'		=> undef,
		'log_from_address'	=> 'UglyMUG Logs <uglylogs@uglymug.org.uk>',
		'admin_info'		=> undef,
		'gzip_large_logs'	=> 1,			# by default use gzip to shrink massive logs
		'gzip_size'			=> 1048576,		# 1Mb

		# set this to a valid email address
		# if you want to DEBUG logs by sending ALL messages
		'test_mail_to'		=> undef,

		# set this to 'perl true' if you
		# want all messages printed to STDOUT
		'test_print_mail'	=> 0,
	};

	# loop through $self->{'_conf'}, if we have been passed a parameter with the same name, set it
	foreach my $option (keys %{$self->{'_conf'}}) {
		if (exists $params->{$option}) {
			$self->{'_conf'}{$option} = $params->{$option};
		}
	}

	# we need to know the log-root directory
	if (defined $self->{'_conf'}{'log_root'}) {
		# does it exist?
		if (-d $self->{'_conf'}{'log_root'}) {
			# $self->{'_conf'}{'log_root'} = $params->{'log_root'};
			# everything fine
		}
		elsif (-e $self->{'_conf'}{'log_root'}) {
			# it exists, but isn't a directory
			warn qq[log_root: not a directory: $self->{'_conf'}{'log_root'}\n];
			exit;
		}
		else {
			# darn thing doesn't exist
			warn "log root: $self->{'_conf'}{'log_root'} doesn't exist\n";
			exit;
		}
	}
	else {
		warn "log_root was not specified in @{[ref($self)]}->new\n";
		exit;
	}

	# if log_header_root is provided, run the usual checks
	# if it isn't, then assume ${log_root}/headers
	if ($self->{'_conf'}{'log_header_root'}) {
		if (-d $self->{'_conf'}{'log_header_root'}) {
			#$self->{'_conf'}{'log_header_root'} = $params->{'log_header_root'};
		}
		elsif (-e $params->{'log_header_root'}) {
			warn qq[log_header_root: not a directory: $self->{'_conf'}{'log_header_root'}\n];
		}
		else {
			# we've been given sonething that doesn't exist
			warn qq[log_header_root: $self->{'_conf'}{'log_header_root'} does not exist\n];
		}
	}
	else {
		# use ${log_root}/headers
		if (-d "$self->{'_conf'}{'log_root'}/headers") {
			$self->{'_conf'}{'log_header_root'} = "$self->{'_conf'}{'log_root'}/headers";
		}
		else {
			warn qq[$self->{'_conf'}{'log_root'}/headers is not a valid header directory\n];
			exit;
		}
	}

	# we need to know the email list so that we can pass it on to UglyMUG::Player::Email
	if (defined $self->{'_conf'}{'email_list'}) {
		# does the file exist
		if (-f $self->{'_conf'}{'email_list'}) {
			#$self->{'_conf'}{'email_list'} = $params->{'email_list'};
		}
		else {
			warn qq[can not use $self->{'_conf'}{'email_list'} as an email list\n];
			exit;
		}
	}
	else {
		# not specified? needs to be
		warn qq[email_list not specified in @{[ref($self)]}->new\n];
		exit;
	}

	# pre-load an instance of UglyMUG::Player::Email
	$self->{'_module'}{'player_email'} = UglyMUG::Player::Email->new (
		'list'		=> $self->{'_conf'}{'email_list'},		# player information
		'cache'		=> 1,									# read and store information
	);

	# pre-load an instance of UglyMUG::Log::Admin
	$self->{'_module'}{'log_admin'} = UglyMUG::Log::Admin->new (
		'admin_info'	=> $self->{'_conf'}{'admin_info'},	# admin logs req'd info
		'email_list'	=> $self->{'_conf'}{'email_list'},	# player information
		'auto_write'	=> 0,								# since we are only retrieving information
	);

	return;
}

=head2 send_player_log($self, $playerid, $log)

This will send E<lt>logrootE<gt>/player/E<lt>playeridE<gt>/E<lt>logE<gt>
in an email, with any appropriate headers - if the required file
exists.

This should be used for sending player logs - B<note> and B<Huh>.

  # finished processing logs - send Chisel his huh and note
  $chisel = #24235;
  $log_email->send_player_log($chisel, 'huh');
  $log_email->send_player_log($chisel, 'note');

=cut
sub send_player_log($$$) {
	my ($self, $playerid, $log) = @_;

	# look for the log file
	if (-f "$self->{'_conf'}{'log_root'}/player/$playerid/$log") {
		my ($hdr, $ftr, $data, $to);

		# read the file
		open (LOG, "<$self->{'_conf'}{'log_root'}/player/$playerid/$log") 
			or do {
				warn "can't open $self->{'_conf'}{'log_root'}/player/$playerid/$log for reading: $!\n";
				return undef;
			};

		# read the file with the log data
		local $/	= undef;		# enable slurp mode
		$data		= <LOG>;
		close LOG;

		# don't send nothing (an extra safety check)
		if (not $data) {
			warn "$self->{'_conf'}{'log_root'}/player/$playerid/$log appears to be empty\n";
			return undef;
		}

		# get header/footer for the log type
		$hdr = $self->_get_player_mail_header($log);
		$ftr = $self->_get_player_mail_footer($log);

		# prepend header / append footer if appropriate
		$data	= "${hdr}${data}"		if $hdr;
		$data	= "${data}${ftr}"		if $ftr;


		# work out who the message should be sent to
		$to = $self->{'_module'}{'player_email'}->get_formatted_email_address($playerid);

		# make sure it looks right with Email::Valid
		if (not defined $to) {
			warn "player #$playerid does not have an RFC822 compliant email address\n";
			return;
		}

		# capitalise the $log type so we can put it into the Subject
		$log =~ s:^(.)(.+)$:\u$1\L$2\E:;

		# pass the data on to be sent
		$self->_send_email(
			'To'		=> $to,
			'Subject'	=> "[UglyMUG] Player $log Log",
			'Data'		=> $data,

			'X-Hdr'	=> {
				'UglyMUG-Player-ID'		=> $playerid,
			},
		);
	}
	else {
		warn "$self->{'_conf'}{'log_root'}/player/$playerid/$log is not a file\n";
	}
}

=head2 send_admin_log($self, $type, $log)

This will send E<lt>logrootE<gt>/admin/E<lt>typeE<gt>/E<lt>logE<gt>
to all admin who are set (using UglyMUG::Log::Admin) to receive
logs of this type.

=cut
sub send_admin_log($$$) {
	my ($self, $type, $log) = @_;

	# look for the log file
	if (-f "$self->{'_conf'}{'log_root'}/admin/$type/$log") {
		my ($hdr, $ftr, $data, $attach);

		# default to NO file attachment
		$attach = undef;

		# is the file waaaaay too big?
		if ( $self->{'_conf'}{'gzip_large_logs'} and _log_filesize("$self->{'_conf'}{'log_root'}/admin/$type/$log") > $self->{'_conf'}{'gzip_size'}) {
			# we want to compress large files, and this is a big bugger
			if (defined _gzip_file("$self->{'_conf'}{'log_root'}/admin/$type/$log")) {
				$attach = "$self->{'_conf'}{'log_root'}/admin/$type/$log.gz";
			}

			# put a short explanation in the message body
			$data = "This file exceeded the limit set for data to be included in\nthe body of the email.\n\nPlease check the attached file.\n";

			# if $attach isn't defined we failed to gzip it - mention this
			if (not defined $attach) {
				$data .= "\n*** failed to create compressed log - no file will be attached ***\n\n";
			}
		}
		else {
			# just put the file in the message body

			# read the file
			open (LOG, "<$self->{'_conf'}{'log_root'}/admin/$type/$log")
				or do {
					warn "can't open $self->{'_conf'}{'log_root'}/admin/$type/$log for reading: \n";
					return undef;
				};

			# read the file with the log data
			local $/	= undef;	# enable slurp mode
			$data		= <LOG>;
			close LOG;
		}

		# get header/footer for the log type
		$hdr = $self->_get_admin_mail_header($type, $log);
		$ftr = $self->_get_admin_mail_footer($type, $log);

		# don't send nothing
		if (not($data)) {
			warn "$self->{'_conf'}{'log_root'}/admin/$type/$log appears to be empty\n";
			return undef;
		}

		# prepend header / append footer if appropriate
		$data	= "${hdr}${data}"		if $hdr;
		$data	= "${data}${ftr}"		if $ftr;

		# build the To/Cc/Bcc list - whichever we decide to use
		my ($recipients, $to_list);
		$recipients = $self->{'_module'}{'log_admin'}->wants_log($log);
		$to_list	= $self->{'_module'}{'log_admin'}->build_recipient_string($recipients);

		# capitalise the $log type so we can put it into the Subject
		$log =~ s:(.)(.+)$:\u$1\L$2\E:;
		# pass on the data so that it can be emailed
		# only send if there are players listed in the to_list
		if ($to_list ne '') {
			$self->_send_email(
				'Bcc'		=> $to_list,
				'Subject'	=> "[UglyMUG] $log Log",
				'Data'		=> $data,
				'Attach'	=> $attach,
			);
		}
		else {
			warn "No recipients for: UglyMUG $log Log\n";
		}
	}
	else {
		warn "$self->{'_conf'}{'log_root'}/admin/$type/$log is not a file\n";
	}
}


=head1 PRIVATE METHODS

These methods are B<PRIVATE> to this module.
If you find yourself using any of these outside
this module, something isn't correct, and you should
contact the module author

=cut

=head2 _send_email ($self, option => value, ...)

This function is a wrapper around MIME::Lite calls.
It checks that we have the miminal data to send an
email, builds it, and send it.

The following options are recognised:

=over 4

=item * To

The recipient of the email

=item * Cc

Who to send a carcon-copy of the email to

=item * Bcc

Who to send a blind-carbon-copy of the email to.
This is used for sending admin logs - one outgoing
mail per log, rather than one email per admin per log.

=item * Subject

The subject line of the outgoing email

=item * Data

The message body

=item * Attach

A filename to be attached to the message

=item * X-Hdr

This is a hash of extra headers to set.
Each header will automatically prefixed by X-
so you should send 'MyHeader' not 'X-MyHeader'
(unless of course you want X-X-MyHeader!)

=back

You must have B<at least one of> To, Cc, Bcc.
Both Subject and Data are B<compulsory>.
X-Hdr is entirely optional.

Example:
  $self->_send_email(
     'To'       => 'me@mydomain.com',
     'Subject'  => 'A log or something',
     'Data'     => $msg_body,
     'X-Hdr' => {
        'Day'   => 'Monday',
     },
  );

=cut
sub _send_email {
	my ($self, %param) = @_;
	my ($msg);

	# these parameters are compulsory
	for my $p (qw[Subject Data]) {
		if (not exists $param{$p}) {
			warn "required parameter '$p' missing in call to _send_email()";
			return undef;
		}
	}

	# we need at least one of these
	my $optional_count = 0;
	for my $p (qw[To Cc Bcc]) {
		$optional_count++	if (exists($param{$p}));
	}
	if ($optional_count < 1) {
		warn "you must past one of To, Cc, Bcc as a parameter to _send_email()";
		return undef;
	}

	# build an email message
	$msg = MIME::Lite->new (
		'From'			=> $self->{'_conf'}{'log_from_address'},
		
		'To'			=> $param{'To'},
		'Cc'			=> $param{'Cc'},
		'Bcc'			=> $param{'Bcc'},

		'Subject'		=> $param{'Subject'},

		'Type'			=> 'TEXT',
		'Data'			=> $param{'Data'},
	);

	# attach a file?
	if (defined $param{'Attach'} and -f $param{'Attach'}) {
		my ($file, $path);

		($file) = (
			$param{'Attach'} =~
			m:^					# start of the line
			  .+				# anything (greedy)
			  /					# the final slash
			  ([^/]+)			# anything not a slash - $file
			  $					# end of the line
			  :x );


		$msg->attach(
			'Type'		=> 'AUTO',
			'Filename'	=> $file,
			'Path'		=> $param{'Attach'},
		) or warn "couldn't attach $param{'Attach'}";
	}

	# add any extra headers
	while (my ($xhdr, $value) = each %{$param{'X-Hdr'}}) {
		$msg->add("X-${xhdr}", $value);
	}

	# if we are testing by sending logs to one
	# test address
	if (defined $self->{'_conf'}{'test_mail_to'}) {
		# change the To/Cc/Bcc
		for my $fld (qw{To Cc Bcc}) {
			if ($param{$fld}) {
				# remove the existing header
				$msg->delete($fld);
				# add the new one
				$msg->add($fld, $self->{'_conf'}{'test_mail_to'});
				# put the intended recipient in the header
				$msg->add("X-UglyMUG-Recipient_$fld", $param{$fld});
			}
		}
	}

	# print to stdout? or send the message?
	if ($self->{'_conf'}{'test_print_mail'}) {
		print "*" x 100, "\n";
		print $msg->as_string;
		print "*" x 100, "\n";
	}
	else {
		$msg->send;
	}
}

# OK, I know; _get_(player|admin)_mail_(header|footer) have chunks of copied and pasted
# code; this is Bad, and should be written so that the common chunk(s) are split out
# into function(s)

sub _get_player_mail_header($$) {
	#   <header-root>/header.player.<note|huh>
	my ($self, $log) = @_;
	my ($header);

	if (-f "$self->{'_conf'}{'log_header_root'}/header.player.$log") {
		open (HDR, "<$self->{'_conf'}{'log_header_root'}/header.player.$log")
			or do {
				warn "can't open $self->{'_conf'}{'log_header_root'}/header.player.$log for reading: $!\n";
				return undef;
			};

		local $/ = undef;		# enable slurp mode
		$header = <HDR>;
		close HDR;
		return $header;
	}
	else {
		warn "header: $self->{'_conf'}{'log_header_root'}/header.player.$log does not exist\n";
		return undef;
	}
}

sub _get_player_mail_footer($$) {
	#   <header-root>/footer.player.<note|huh>
	my ($self, $log) = @_;
	my ($footer);

	if (-f "$self->{'_conf'}{'log_header_root'}/footer.player.$log") {
		open (FTR, "<$self->{'_conf'}{'log_header_root'}/footer.player.$log")
			or do {
				warn "can't open $self->{'_conf'}{'log_header_root'}/footer.player.$log for reading: $!\n";
				return undef;
			};

		local $/ = undef;		# enable slurp mode
		$footer = <FTR>;
		close FTR;
		return $footer;
	}
	else {
		warn "footer: $self->{'_conf'}{'log_header_root'}/footer.player.$log does not exist\n";
		return undef;
	}
}

sub _get_admin_mail_header($$$) {
	#   <header-root>/header.admin.<day|keep>.<log>
	my ($self, $type, $log) = @_;
	my ($header);

	if (-f "$self->{'_conf'}{'log_header_root'}/header.admin.$type.$log") {
		open (HDR, "<$self->{'_conf'}{'log_header_root'}/header.admin.$type.$log")
			or do {
				warn "can't open $self->{'_conf'}{'log_header_root'}/header.admin.$type.$log for reading: $!\n";
				return undef;
			};

		local $/	= undef;	# enable slurp mode
		$header		= <HDR>;
		close HDR;
		return $header;
	}
	else {
		warn "header: $self->{'_conf'}{'log_header_root'}/header.admin.$type.$log does not exist\n";
		return undef;
	}
}

sub _get_admin_mail_footer($$$) {
	#   <header-root>/footer.admin.<day|keep>.<log>
	my ($self, $type, $log) = @_;
	my ($footer);

	if (-f "$self->{'_conf'}{'log_header_root'}/footer.admin.$type.$log") {
		open (HDR, "<$self->{'_conf'}{'log_header_root'}/footer.admin.$type.$log")
			or do {
				warn "can't open $self->{'_conf'}{'log_header_root'}/footer.admin.$type.$log for reading: $!\n";
				return undef;
			};

		local $/	= undef;	# enable slurp mode
		$footer		= <HDR>;
		close HDR;
		return $footer;
	}
	else {
		warn "footer: $self->{'_conf'}{'log_header_root'}/footer.admin.$type.$log does not exist\n";
		return undef;
	}
}


=head2 _log_filesize($filename)

This function simply returns the size of a given file in bytes.
If the file doesn't exist -1 is returned.

=cut
sub _log_filesize($) {
	my ($file) = @_;
	if (! -f $file) {
		return -1;
	}
	else {
		my $size;
		$size = (stat($file))[7];
		return $size;
	}
}

=head2 _gzip_file($infile [, $outfile])

This function takes $infile and compresses it.
If $outfile is B<not> specified the outfile
is set to "$infile.gz".

Returns 1 for success, or undef for failure.

=cut
sub _gzip_file($;$) {
	my $infile	= shift;
	my $outfile	= shift || "${infile}.gz";

	open (TOZIP, "<$infile")
		or do {
			warn "can't open $infile: $!";
			return undef;
		};

	open (OUTZIP, ">$outfile")
		or do {
			warn "can't open $outfile: $!";
			return undef;
		};

	binmode TOZIP;

	my $gz = gzopen(\*OUTZIP, "wb")
		or do {
			warn "Cannot open file: $gzerrno";
			return undef;
		};

	while (<TOZIP>) {
		$gz->gzwrite($_)
			or do {
				warn "error writing $outfile: $gzerrno";
				$gz->gzclose;
				return undef;
			}
	}

	$gz->gzclose;
	close OUTZIP;
	close TOZIP;

	return 1;
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
