package Data::Schema::Type::Bool;

=head1 NAME

Data::Schema::Type::Bool - Type handler for booleans ('bool')

=head1 SYNOPSIS

 use Data::Schema;

=head1 DESCRIPTION

This is the type handler for type 'bool'.

Synonyms: boolean

=cut

use Moose;
extends 'Data::Schema::Type::Base';

sub cmp {
    my ($self, $a, $b) = @_;
    ($a ? 1:0) <=> ($b ? 1:0);
    # true is considered larger than false
}

sub type_in_english {
    "bool";
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
