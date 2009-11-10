package Data::Schema::Type::HasElement;

use Moose::Role;

=head1 NAME

Data::Schema::Type::HasElement - Role for types that have the notion of elements

=head1 SYNOPSIS

    use Data::Schema;

=head1 DESCRIPTION

This is the role for types that have the notion of length. It provides
attributes like maxlen, length, length_between, all_elements, etc. It is used by
'str', 'array', and also 'hash'.

Role consumer must provide methods:

* '_length()' which returns the length;

* '_element(idx)' which returns the element at idx;

* '_indexes()' which returns all element indexes.

=cut

requires '_length', '_element', '_indexes';

=head1 TYPE ATTRIBUTES

=head2 max_len => LEN

Requires that the array have at most LEN elements.

Synonyms: maxlen, max_length, maxlength

=cut

sub handle_attr_max_len {
    my ($self, $data, $arg) = @_;
    if ($self->_length($data) > $arg) {
        $self->validator->log_error("length must not exceed $arg");
        return;
    }
    1;
}

# aliases
sub handle_attr_maxlen { handle_attr_max_len(@_) }
sub handle_attr_max_length { handle_attr_max_len(@_) }
sub handle_attr_maxlength { handle_attr_max_len(@_) }

=head2 min_len => LEN

Requires that the array have at least LEN elements.

Synonyms: minlen, min_length, minlength

=cut

sub handle_attr_min_len {
    my ($self, $data, $arg) = @_;
    if ($self->_length($data) < $arg) {
        $self->validator->log_error("length must be at least $arg");
        return;
    }
    1;
}

# aliases
sub handle_attr_minlen { handle_attr_min_len(@_) }
sub handle_attr_min_length { handle_attr_min_len(@_) }
sub handle_attr_minlength { handle_attr_min_len(@_) }

=head2 len_between => [MIN, MAX]

A convenience attribute that combines B<minlen> and B<maxlen>.

Synonyms: length_between

=cut

sub handle_attr_len_between {
    my ($self, $data, $arg) = @_;
    my $l = $self->_length($data);
    if ($l < $arg->[0] || $l > $arg->[1]) {
        $self->validator->log_error("length must be between $arg->[0] and $arg->[1])");
        return;
    }
    1;
}

# aliases
sub handle_attr_length_between { handle_attr_len_between(@_) }

=head2 len => LEN

Requires that the array have exactly LEN elements.

Synonyms: length

=cut

sub handle_attr_len {
    my ($self, $data, $arg) = @_;
    if ($self->_length($data) != $arg) {
        $self->validator->log_error("length must be $arg");
        return;
    }
    1;
}

# aliases
sub handle_attr_length { handle_attr_len(@_) }

=head2 all_elements => SCHEMA

Requires that every element of the array validates to the specified schema.

Synonyms: all_element, all_elems, all_elem

Example (in YAML):

 [array, {of: int}]

The above specifies an array of ints.

=cut

sub handle_attr_all_elements {
    my ($self, $data, $arg) = @_;
    my $has_err = 0;

    my @indexes = $self->_indexes($data);
    push @{ $self->validator->data_pos }, $indexes[0];
    for my $i (@indexes) {
        $self->validator->data_pos->[-1] = $i;
        if (!$self->validator->_validate($self->_element($data, $i), $arg)) {
            $has_err++;
        }
        last if $self->validator->too_many_errors;
    }
    pop @{ $self->validator->data_pos };
    !$has_err;
}

# aliases
sub handle_attr_all_element { handle_attr_all_elements(@_) }
sub handle_attr_all_elems { handle_attr_all_elements(@_) }
sub handle_attr_all_elem { handle_attr_all_elements(@_) }

sub _for_each_element {
    my ($self, $data, $arg, $checkfail_sub) = @_;
    my $has_err = 0;

    my @indexes = $self->_indexes($data);
    push @{ $self->validator->data_pos }, $indexes[0];
    foreach my $k (@indexes) {
        my $v = $self->_element($data, $k);
        $self->validator->data_pos->[-1] = $k;
        my $errmsg = $checkfail_sub->($k, $v, $arg);
        if ($errmsg) {
            $has_err++;
            $self->validator->log_error($errmsg);
            last if $self->validator->too_many_errors;
        }
    }
    pop @{ $self->validator->data_pos };
    !$has_err;
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
