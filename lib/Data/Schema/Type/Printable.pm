package Data::Schema::Type::Printable;

use Moose::Role;

=head1 NAME

Data::Schema::Type::Printable - Role for printable stuff

=head1 SYNOPSIS

    use Data::Schema;

=head1 DESCRIPTION

This is the printable role. It just requires that consumer provide method
'_dump' to return a string representation of itself.

=cut

requires '_dump';

no Moose::Role;
1;
