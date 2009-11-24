package Data::Schema::Type::Printable;
our $VERSION = '0.12';


# ABSTRACT: Role for printable stuff


use Moose::Role;

requires map { ("_$_", "_emitpl_$_") } qw/dump perl/;

no Moose::Role;
1;

__END__
=pod

=head1 NAME

Data::Schema::Type::Printable - Role for printable stuff

=head1 VERSION

version 0.12

=head1 SYNOPSIS

    use Data::Schema;

=head1 DESCRIPTION

This is the printable role. It just requires that consumer provide method
'_dump' to return a string representation of itself and '_perl' to return a
valid Perl literal for that value.

=head1 AUTHOR

  Steven Haryanto <stevenharyanto@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2009 by Steven Haryanto.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

