package Data::Schema::Type::Float;

=head1 NAME

Data::Schema::Type::Float - Type handler for floating point numbers ('float')

=head1 SYNOPSIS

 use Data::Schema;

=head1 DESCRIPTION

This is the type handler for type 'float'.

=cut

use Moose;
extends 'Data::Schema::Type::Num';

override handle_pre_check_attrs => sub {
    super(@_);
    # XXX extra check when Num support other non-floats, e.g. complex, rational
};

sub type_in_english {
    "float";
}

=head1 TYPE ATTRIBUTES

See L<Data::Schema::Type::Base>.

=head1 AUTHOR

Steven Haryanto, C<< <steven at masterweb.net> >>

=head1 COPYRIGHT & LICENSE

Copyright 2009 Steven Haryanto, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut

__PACKAGE__->meta->make_immutable;
1;
