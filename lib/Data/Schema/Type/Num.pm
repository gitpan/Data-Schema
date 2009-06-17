package Data::Schema::Type::Num;

=head1 NAME

Data::Schema::Type::Num - Base type handler for numbers

=head1 SYNOPSIS

 # see subclasses, like DST::Int or DST::Float

=head1 DESCRIPTION

This is base class for number types, like 'int' and 'float'.

=cut

use Moose;
extends 'Data::Schema::Type::Base';
use Scalar::Util qw/looks_like_number/;

sub cmp {
    my ($self, $a, $b) = @_;
    $a <=> $b;
}

sub handle_pre_check_attrs {
    my ($self, $data) = @_;
    if (!looks_like_number($data)) {
        $self->validator->log_error("data not a number");
        return;
    }
    1;
}

=head1 AUTHOR

Steven Haryanto, C<< <steven at masterweb.net> >>

=head1 COPYRIGHT & LICENSE

Copyright 2009 Steven Haryanto, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut

__PACKAGE__->meta->make_immutable;
1;
