package Data::Schema::Type::Int;

=head1 NAME

Data::Schema::Type::Int - Type handler for integer numbers ('int')

=head1 SYNOPSIS

 use Data::Schema;

=head1 DESCRIPTION

This is the type handler for type 'int'.

=cut

use Moose;
extends 'Data::Schema::Type::Num';

override handle_pre_check_attrs => sub {
    return unless super(@_);
    my ($self, $data) = @_;
    if ($data != int($data)) {
        $self->validator->log_error("data not an integer");
        return;
    }
    1;
};

=head1 TYPE ATTRIBUTES

In addition to attributes provided from L<Data::Schema::Type::Base>,
e.g. B<one_of> or B<min> and B<max>, ints have additional attributes.

=head2 mod => [X, Y]

Require that (data mod X) equals Y. For example, mod => [2, 1]
effectively specifies odd numbers.

=cut

sub handle_attr_mod {
    my ($self, $data, $args) = @_;

    if (($data % $args->[0]) != $args->[1]) {
        $self->validator->log_error("data mod $args->[0] must be $args->[1]");
        return;
    }
    1;
}

=head2 divisible_by => X

Require that (data mod X) equals 0.

=cut

sub handle_attr_divisible_by {
    my ($self, $data, $args) = @_;
    if ($data % $args) {
        $self->validator->log_error("must be divisible by $args");
        return;
    }
    1;
}

=head2 not_divisible_by => X

Require that (data mod X) not equals 0.

Synonyms: undivisible_by

=cut

sub handle_attr_not_divisible_by {
    my ($self, $data, $args) = @_;
    if ($data % $args == 0) {
        $self->validator->log_error("must not be divisible by $args");
        return;
    }
    1;
}

# aliases
sub handle_attr_undivisible_by { handle_attr_not_divisible_by(@_) }

sub type_in_english {
    "int";
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
