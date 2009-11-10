package Data::Schema::Type::Str;

=head1 NAME

Data::Schema::Type::Str - Type handler for string ('str')

=head1 SYNOPSIS

 use Data::Schema;

=head1 DESCRIPTION

This is type handler for 'str'.

=cut

use Moose;
extends 'Data::Schema::Type::Base';
with 'Data::Schema::Type::Comparable', 'Data::Schema::Type::Sortable', 'Data::Schema::Type::HasLength';

sub _equal {
    my ($self, $a, $b) = @_;
    $a eq $b;
}

sub _compare {
    my ($self, $a, $b) = @_;
    $a cmp $b;
}

sub _length {
    my ($self, $data) = @_;
    length($data);
}

sub _rematch {
    my ($self, $str, $re) = @_;
    $str =~ qr/$re/;
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

Strings are Comparable, Sortable, and HasLength, so you might want to consult
the docs of those roles to see what type attributes are available.

In addition to these, string has some additional attributes:

=head2 match => REGEX

Require that the string match a regular expression.

Synonyms: matches

=cut

sub handle_attr_match {
    my ($self, $data, $arg) = @_;
    if (!$self->_rematch($data, $arg)) {
        $self->validator->log_error("must match regex $arg");
        return;
    }
    1;
}

# aliases
sub handle_attr_matches { handle_attr_match(@_) }

=head2 not_match => REGEX

The opposite of B<match>, require that the string not match a regular expression.

Synonyms: not_matches

=cut

sub handle_attr_not_match {
    my ($self, $data, $arg) = @_;
    if ($self->_rematch($data, $arg)) {
        $self->validator->log_error("must not match regex $arg");
        return;
    }
    1;
}

# aliases
sub handle_attr_not_matches { handle_attr_not_match(@_) }

sub english {
    "string";
}

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
