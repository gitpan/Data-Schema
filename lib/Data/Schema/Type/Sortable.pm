package Data::Schema::Type::Sortable;

use Moose::Role;

=head1 NAME

Data::Schema::Type::Sortable - Role for sortable types

=head1 SYNOPSIS

    use Data::Schema;

=head1 DESCRIPTION

This is the sortable role. It provides attributes like less_than (lt),
greater_than (gt), etc. It is used by many types, for example 'str', all numeric
types, etc.

Role consumer must provide method '_compare' which takes two values and returns
-1, 0, or 1 a la Perl's standard B<cmp> operator.

=cut

with 'Data::Schema::Type::Printable';
requires '_compare';

=head1 TYPE ATTRIBUTES

=head2 min => MIN

Require that the value is not less than some specified minimum.

Synonyms: ge

=cut

sub handle_attr_min {
    my ($self, $data, $arg) = @_;
    if ($self->_compare($data, $arg) < 0) {
        $self->validator->log_error("value too small, min is $arg");
        return 0;
    }
    1;
}

# aliases
sub handle_attr_ge { handle_attr_min(@_) }

=head2 minex => MIN

Require that the value is not less or equal than some specified minimum.

Synonyms: gt

=cut

sub handle_attr_minex {
    my ($self, $data, $arg) = @_;
    if ($self->_compare($data, $arg) <= 0) {
        $self->validator->log_error("value must be greater than $arg");
        return 0;
    }
    1;
}

# aliases
sub handle_attr_gt { handle_attr_minex(@_) }

=head2 max => MAX

Require that the value is less or equal than some specified maximum.

Synonyms: le

=cut

sub handle_attr_max {
    my ($self, $data, $arg) = @_;
    if ($self->_compare($data, $arg) > 0) {
        $self->validator->log_error("value too large, max is $arg");
        return 0;
    }
    1;
}

# aliases
sub handle_attr_le { handle_attr_max(@_) }

=head2 maxex => MAX

Require that the value is less than some specified maximum.

Synonyms: lt

=cut

sub handle_attr_maxex {
    my ($self, $data, $arg) = @_;
    if ($self->_compare($data, $arg) >= 0) {
        $self->validator->log_error("value must be less than $arg");
        return 0;
    }
    1;
}

# aliases
sub handle_attr_lt { handle_attr_maxex(@_) }

=head2 between => [MIN, MAX]

A convenient attribut to combine B<min> and B<max>.

=cut

sub handle_attr_between {
    my ($self, $data, $arg) = @_;
    $self->handle_attr_min($data, $arg->[0]) &&
    $self->handle_attr_max($data, $arg->[1]);
}

=head1 AUTHOR

Steven Haryanto, C<< <steven at masterweb.net> >>

=head1 COPYRIGHT & LICENSE

Copyright 2009 Steven Haryanto, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut

no Moose::Role;
1;
