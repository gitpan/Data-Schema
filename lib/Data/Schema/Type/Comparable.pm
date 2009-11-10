package Data::Schema::Type::Comparable;

use Moose::Role;

=head1 NAME

Data::Schema::Type::Comparable - Role for comparable types

=head1 SYNOPSIS

    use Data::Schema;

=head1 DESCRIPTION

This is the comparable role. It provides attributes like is,
one_of, etc. It is used by most types, for example 'str', all numeric types,
etc.

Role consumer must provide method '_equal' which takes two values and returns 0
or 1 depending on whether the values are equal.

=cut

with 'Data::Schema::Type::Printable';
requires '_equal';

=head1 TYPE ATTRIBUTES

=head2 one_of => [value1, ...]

Require that the data is one of the specified choices.

Synonyms: is_one_of

=cut

sub handle_attr_one_of {
    my ($self, $data, $arg) = @_;
    for (@$arg) {
        return 1 if $self->_equal($data, $_);
    }
    my $msg;
    if (@$arg == 1) {
        $msg = "data must be ".$self->_dump($arg->[0]);
    } elsif (@$arg <= 10) {
        $msg = "data must be one of [".join(", ", map {$self->_dump($_)} @$arg)."]";
    } else {
        $msg = "data doesn't belong to a list of valid values";
    }
    $self->validator->log_error($msg);
    0;
}

# aliases
sub handle_attr_is_one_of { handle_attr_one_of(@_) }

=head2 not_one_of => [value1, ...]

Require that the data is not listed in one of the specified "blacklists".

Synonyms: isnt_one_of

=cut

sub handle_attr_not_one_of {
    my ($self, $data, $arg) = @_;
    for (@$arg) {
        if ($self->_equal($data, $_)) {
            my $msg;
            if (@$arg == 1) {
                $msg = "data must not be ".$self->_dump($arg->[0]);
            } elsif (@$arg <= 10) {
                $msg = "data must not be one of [".join(", ", map {$self->_dump($_)} @$arg)."]";
            } else {
                $msg = "data belongs to a list of invalid values";
            }
            $self->validator->log_error($msg);
            return 0;
        }
    }
    1;
}

# aliases
sub handle_attr_isnt_one_of { handle_attr_not_one_of(@_) }

=head2 is => value

A convenient attribute for B<one_of> when there is only one choice.

=cut

=head2 is => value

A convenient attribute for B<one_of> when there is only one choice.

=cut

sub handle_attr_is {
    my ($self, $data, $arg) = @_;
    $self->handle_attr_one_of($data, [$arg]);
}

=head2 isnt => value

A convenient attribute for B<not_one_of> when there is only one item in the
blacklist.

Synonyms: not

=cut

# convenience method for only a single invalid value
sub handle_attr_isnt {
    my ($self, $data, $arg) = @_;
    $self->handle_attr_not_one_of($data, [$arg]);
}

# aliases
sub handle_attr_not { handle_attr_isnt(@_) }

=head1 AUTHOR

Steven Haryanto, C<< <steven at masterweb.net> >>

=head1 COPYRIGHT & LICENSE

Copyright 2009 Steven Haryanto, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut

no Moose::Role;
1;
