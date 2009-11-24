package Data::Schema::Type::Str;
our $VERSION = '0.12';


# ABSTRACT: Type handler for string ('str')


use Moose;
extends 'Data::Schema::Type::Base';
with
    'Data::Schema::Type::Comparable',
    'Data::Schema::Type::Sortable',
    'Data::Schema::Type::HasElement' => { -excludes => ['handle_attr_deps', 'emitpl_attr_deps'] },
    'Data::Schema::Type::Scalar';

sub _equal {
    my ($self, $a, $b) = @_;
    $a eq $b;
}

sub _emitpl_equal {
    my ($self, $a, $b) = @_;
    "(($a) eq ($b))";
}

sub _compare {
    my ($self, $a, $b) = @_;
    $a cmp $b;
}

sub _emitpl_compare {
    my ($self, $a, $b) = @_;
    "(($a) cmp ($b))";
}

sub _length {
    my ($self, $data) = @_;
    length($data);
}

sub _emitpl_length {
    my ($self, $data) = @_;
    "(length($data))";
}

sub _element {
    my ($self, $data, $idx) = @_;
    substr($data, $idx, 1);
}

sub _emitpl_element {
    my ($self, $data, $idx) = @_;
    "(substr($data, $idx, 1))";
}

sub _indexes {
    my ($self, $data) = @_;
    0..length($data)-1;
}

sub _emitpl_indexes {
    my ($self, $data) = @_;
    "(0..length($data)-1)";
}

sub _rematch {
    my ($self, $str, $re) = @_;
    $str =~ qr/$re/;
}

sub _emitpl_rematch {
    my ($self, $str, $re) = @_;
    $re = qr/$re/ unless ref($re) eq 'Regexp';
    "($str =~ ".$self->_dump($re).")";
}

sub handle_pre_check_attrs {
    my ($self, $data) = @_;
    if (ref($data)) {
        $self->validator->data_error("data not a string");
        return;
    }
    1;
}

sub emitpl_pre_check_attrs {
    my ($self) = @_;
    'if (ref($data)) { '.$self->validator->emitpl_data_error("data not a string").'; pop @$schemapos; last L1 }'."\n";
}


sub handle_attr_match {
    my ($self, $data, $arg) = @_;
    if (!$self->_rematch($data, $arg)) {
        $self->validator->data_error("must match regex $arg");
        return;
    }
    1;
}

sub emitpl_attr_match {
    my ($self, $arg) = @_;
    'if (!'.$self->_emitpl_rematch('$data', $arg).') { '.$self->validator->emitpl_data_error("must match regex $arg")." }\n";
}

# aliases
sub handle_attr_matches { handle_attr_match(@_) }
sub emitpl_attr_matches { emitpl_attr_match(@_) }


sub handle_attr_not_match {
    my ($self, $data, $arg) = @_;
    if ($self->_rematch($data, $arg)) {
        $self->validator->data_error("must not match regex $arg");
        return;
    }
    1;
}

sub emitpl_attr_not_match {
    my ($self, $arg) = @_;
    'if ('.$self->_emitpl_rematch('$data', $arg).') { '.$self->validator->emitpl_data_error("must match regex $arg")." }\n";
}

# aliases
sub handle_attr_not_matches { handle_attr_not_match(@_) }
sub emitpl_attr_not_matches { emitpl_attr_not_match(@_) }

sub short_english {
    "string";
}

sub english {
    "string";
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;

__END__
=pod

=head1 NAME

Data::Schema::Type::Str - Type handler for string ('str')

=head1 VERSION

version 0.12

=head1 SYNOPSIS

 use Data::Schema;

=head1 DESCRIPTION

This is type handler for 'str'.

=head1 TYPE ATTRIBUTES

Strings are Comparable, Sortable, and HasLength, so you might want to consult
the docs of those roles to see what type attributes are available.

In addition to these, string has some additional attributes:

=head2 match => REGEX

Require that the string match a regular expression.

Synonyms: matches

=head2 not_match => REGEX

The opposite of B<match>, require that the string not match a regular expression.

Synonyms: not_matches

=head1 AUTHOR

  Steven Haryanto <stevenharyanto@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2009 by Steven Haryanto.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

