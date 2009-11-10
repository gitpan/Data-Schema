package Data::Schema::Type::CIStr;

=head1 NAME

Data::Schema::Type::CIStr - Type handler for case-insensitive string ('cistr')

=head1 SYNOPSIS

 use Data::Schema;

=head1 DESCRIPTION

This is type handler for 'cistr'. 'cistr' is just like 'str' except that
comparison/sorting/regex matching is done case-insensitively.

=cut

use Moose;
extends 'Data::Schema::Type::Str';

sub _equal {
    my ($self, $a, $b) = @_;
    lc($a) eq lc($b);
}

sub _compare {
    my ($self, $a, $b) = @_;
    lc($a) cmp lc($b);
}

sub _rematch {
    my ($self, $str, $re) = @_;
    $str =~ qr/$re/i;
}

=head1 SEE ALSO

L<Data::Schema::Type::Str>

=head1 AUTHOR

Steven Haryanto, C<< <steven at masterweb.net> >>

=head1 COPYRIGHT & LICENSE

Copyright 2009 Steven Haryanto, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut

__PACKAGE__->meta->make_immutable;
no Moose;
1;
