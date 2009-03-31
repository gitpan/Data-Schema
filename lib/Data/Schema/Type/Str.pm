package Data::Schema::Type::Str;

=head1 NAME

Data::Schema::Type::Str - Type handler for string ('str')

=head1 SYNOPSIS

 use Data::Schema;

=head1 DESCRIPTION

This is type handler for 'string'.

=cut

use Moose;
extends 'Data::Schema::Type::Base';

sub cmp {
    my ($self, $a, $b) = @_;
    $a cmp $b;
}

sub handle_pre_check_attrs {
    my ($self, $data) = @_;
    if (ref($data)) {
        $self->validator->log_error("data not a string");
        return;
    }
    1;
}

=head1 TYPE ATTRIBUTES

In addition to attributes provided from DST::Base, like B<one_of>, B<is>, etc,
array has some additional attributes:

=head2 len => N

Require that exact length of a string.

Synonyms: length

=cut

sub handle_attr_len {
    my ($self, $data, $arg) = @_;
    if (length($data) != $arg) {
        $self->validator->log_error("length must be $arg");
        return;
    }
    1;
}

# aliases
sub handle_attr_length { handle_attr_len(@_) }

=head2 max_len => N

Require the maximum length of a string.

Synonyms: maxlen, max_length, maxlength

=cut

sub handle_attr_max_len {
    my ($self, $data, $arg) = @_;
    if (length($data) > $arg) {
        $self->validator->log_error("length must not exceed $arg");
        return;
    }
    1;
}

# aliases
sub handle_attr_maxlen { handle_attr_max_len(@_) }
sub handle_attr_max_length { handle_attr_max_len(@_) }
sub handle_attr_maxlength { handle_attr_max_len(@_) }

=head2 min_len => N

Require the minimum length of a string.

Synonyms: minlen, min_length, minlength

=cut

sub handle_attr_min_len {
    my ($self, $data, $arg) = @_;
    if (length($data) < $arg) {
        $self->validator->log_error("length must be at least $arg");
        return;
    }
    1;
}

# aliases
sub handle_attr_minlen { handle_attr_min_length(@_) }
sub handle_attr_min_length { handle_attr_min_len(@_) }
sub handle_attr_minlength { handle_attr_min_len(@_) }

=head2 len_between => [MIN, MAX]

Convenience attribute which combines B<min_len> and B<max_len>.

Synonyms: length_between

=cut

sub handle_attr_len_between {
    my ($self, $data, $arg) = @_;
    my $l = length($data);
    if ($l < $arg->[0] || $l > $arg->[1]) {
        $self->validator->log_error("length must be between $arg->[0] and $arg->[1])");
        return;
    }
    1;
}

# aliases
sub handle_attr_length_between { handle_attr_len_between(@_) }

=head2 regex => REGEX

Require that the string match a regular expression.

Synonyms: regexp

=cut

sub handle_attr_regex {
    my ($self, $data, $arg) = @_;
    if ($data !~ qr/$arg/) {
        $self->validator->log_error("must match regex $arg");
        return;
    }
    1;
}

# aliases
sub handle_attr_regexp { handle_attr_regex(@_) }

=head2 not_regex => REGEX

The opposite of B<regex>, require that the string not match a regular expression.

Synonyms: not_regexp

=cut

sub handle_attr_not_regex {
    my ($self, $data, $arg) = @_;
    if ($data =~ qr/$arg/) {
        $self->validator->log_error("must not match regex $arg");
        return;
    }
    1;
}

# aliases
sub handle_attr_not_regexp { handle_attr_not_regex(@_) }

=head1 AUTHOR

Steven Haryanto, C<< <steven at masterweb.net> >>

=head1 COPYRIGHT & LICENSE

Copyright 2009 Steven Haryanto, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut

__PACKAGE__->meta->make_immutable;
1;
