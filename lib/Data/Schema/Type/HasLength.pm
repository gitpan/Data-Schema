package Data::Schema::Type::HasLength;

use Moose::Role;

=head1 NAME

Data::Schema::Type::HasLength - Role for types that have the notion of length

=head1 SYNOPSIS

    use Data::Schema;

=head1 DESCRIPTION

This is the role for types that have the notion of length. It provides
attributes like maxlen, length, length_between, etc. It is used by 'str',
'array', and also 'hash'.

Role consumer must provide method '_length' which returns the length.

=cut

requires '_length';

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

=head1 AUTHOR

Steven Haryanto, C<< <steven at masterweb.net> >>

=head1 COPYRIGHT & LICENSE

Copyright 2009 Steven Haryanto, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut

no Moose::Role;
1;
