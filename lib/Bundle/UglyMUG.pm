# vi:ts=4:sw=4:
package Bundle::UglyMUG;

# make sure we have a version
use vars qw{ $VERSION };
$VERSION = do{my@r=q$Revision: 1.3 $=~/\d+/g;sprintf '%d.'.'%02d'x$#r,@r};

1;

__END__

=head1 NAME

UglyMUG::Bundle - A bundle to install uglymug related modules

=head1 SYNOPSIS

  perl -MCPAN -e 'install Bundle::UglyMUG'

=head1 CONTENTS


Data::Dumper            - essential for Debugging

MIME::Lite              - used to send email messages

Email::Valid            - used to make sure that emails at least conforms to RFC822

Storable                - used to store admin log settings

Compress::Zlib          - used for compressing large log files

Curses                  - used for curses display (standalone script)

Curses::Widgets         - used for curses display (standalone script)


=head1 DESCRIPTION

This bundle defines all required modules for the UglyMUG perl modules


=head1 AUTHOR

Chisel Wright <chisel@herlpacker.co.uk>, February 2002

=cut
