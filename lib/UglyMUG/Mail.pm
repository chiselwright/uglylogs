# vi:ts=4:sw=4:ai:
# $Id: Mail.pm,v 1.1.1.1 2002/02/20 12:30:44 chiselwright Exp $

package UglyMUG::Mail;

use Data::Dumper;
use Storable;

# global variables
use vars qw{ $VERSION };

# set version using cvs information
$VERSION = do{my@r=q$Revision: 1.1.1.1 $=~/\d+/g;sprintf '%d.'.'%02d'x$#r,@r};

=head1 NAME

UglyMUG::Mail - functions for dealing with returned mail

=head1 VERSION

  $Id: Mail.pm,v 1.1.1.1 2002/02/20 12:30:44 chiselwright Exp $

=head1 DESCRIPTION

This module is used to get player information from undeliverable mail
(bounces). We then keep track of how many bounces a particular address has
had over a period of time.

The module is also used for querying this saved information.
We can set criteria so that, for example, we stop sending logs to a certain
address because they have bounced X messages in Y days.

=cut

=head2 new( option => value )

This function does something

=cut
sub new {
	my $proto		= shift;
	my $class		= ref($proto) || $proto;
	my %params		= @_;
	my $self		= { };

	bless($self, $class);
	$self->_initialise(\%params);

	return $self;
}

sub _initialise($$) {
	my ($self, $params) = @_;

	# default parameters
	$self->{'_conf'} = {
		'bounce_info'	=> undef,
		'message'		=> undef,
	};

	# loop through $self->{'_conf'}, if we have been passed a parameter with the same name, set it
	foreach my $option (keys %{$self->{'_conf'}}) {
			if (exists $params->{$option}) {
					$self->{'_conf'}{$option} = $params->{$option};
			}
	}
}

=head2 get_player_id

This should probably use a Mail module from CPAN.
Mail::Header is irritating though

=cut
sub get_player_id($) {
	my ($self) = @_;
	my (@msg);

	# loop the message
	@msg = split(/\n/, $self->{'_conf'}{'message'});

	for (@msg) {
		next	if ($_ !~ /^X-Uglymug-Player-Id:\s+(\d+)$/);
		$self->{'_data'}{'player_id'} = $1;
		return $1;
	}
}

__END__

This is used for trying to work out what I want to store, use, work out, etc.


bounce_info will probably be a Storable stored file.
we will want to:
	

What will be in it?
	VAR1 = {
		'24235' => {
			'chisel@herlpacker.co.uk' => [
				{time},
				{time},
				{time}
			],
		},
	}



