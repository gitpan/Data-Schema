package Data::Schema::Type::Sortable;
our $VERSION = '0.12';


# ABSTRACT: Role for sortable types


use Moose::Role;
with 'Data::Schema::Type::Printable';
requires map { ("_$_", "_emitpl_$_") } qw/compare/;


sub handle_attr_min {
    my ($self, $data, $arg) = @_;
    if ($self->_compare($data, $arg) < 0) {
        $self->validator->data_error("value too small, min is $arg");
        return 0;
    }
    1;
}

sub emitpl_attr_min {
    my ($self, $arg) = @_;
    'if ('.$self->_emitpl_compare('$data', $self->_perl($arg)).' < 0) { '.$self->validator->emitpl_data_error("value too small, min is $arg")." }\n";
}

# aliases
sub handle_attr_ge { handle_attr_min(@_) }
sub emitpl_attr_ge { emitpl_attr_min(@_) }


sub handle_attr_minex {
    my ($self, $data, $arg) = @_;
    if ($self->_compare($data, $arg) <= 0) {
        $self->validator->data_error("value must be greater than $arg");
        return 0;
    }
    1;
}

sub emitpl_attr_minex {
    my ($self, $arg) = @_;
    'if ('.$self->_emitpl_compare('$data', $self->_perl($arg)).' <= 0) { '.$self->validator->emitpl_data_error("value must be greater than $arg")." }\n";
}

# aliases
sub handle_attr_gt { handle_attr_minex(@_) }
sub emitpl_attr_gt { emitpl_attr_minex(@_) }


sub handle_attr_max {
    my ($self, $data, $arg) = @_;
    if ($self->_compare($data, $arg) > 0) {
        $self->validator->data_error("value too large, max is $arg");
        return 0;
    }
    1;
}

sub emitpl_attr_max {
    my ($self, $arg) = @_;
    'if ('.$self->_emitpl_compare('$data', $self->_perl($arg)).' > 0) { '.$self->validator->emitpl_data_error("value too large, max is $arg")." }\n";
}

# aliases
sub handle_attr_le { handle_attr_max(@_) }
sub emitpl_attr_le { emitpl_attr_max(@_) }


sub handle_attr_maxex {
    my ($self, $data, $arg) = @_;
    if ($self->_compare($data, $arg) >= 0) {
        $self->validator->data_error("value must be less than $arg");
        return 0;
    }
    1;
}

sub emitpl_attr_maxex {
    my ($self, $arg) = @_;
    'if ('.$self->_emitpl_compare('$data', $self->_perl($arg)).' >= 0) { '.$self->validator->emitpl_data_error("value must be less than $arg")." }\n";
}

# aliases
sub handle_attr_lt { handle_attr_maxex(@_) }
sub emitpl_attr_lt { emitpl_attr_maxex(@_) }


sub handle_attr_between {
    my ($self, $data, $arg) = @_;
    $self->handle_attr_min($data, $arg->[0]) &&
    $self->handle_attr_max($data, $arg->[1]);
}

sub emitpl_attr_between {
    my ($self, $arg) = @_;
    $self->emitpl_attr_min($arg->[0]).
    $self->emitpl_attr_max($arg->[1]);
}

no Moose::Role;
1;

__END__
=pod

=head1 NAME

Data::Schema::Type::Sortable - Role for sortable types

=head1 VERSION

version 0.12

=head1 SYNOPSIS

    use Data::Schema;

=head1 DESCRIPTION

This is the sortable role. It provides attributes like less_than (lt),
greater_than (gt), etc. It is used by many types, for example 'str', all numeric
types, etc.

Role consumer must provide method '_compare' which takes two values and returns
-1, 0, or 1 a la Perl's standard B<cmp> operator.

=head1 TYPE ATTRIBUTES

=head2 min => MIN

Require that the value is not less than some specified minimum.

Synonyms: ge

=head2 minex => MIN

Require that the value is not less or equal than some specified minimum.

Synonyms: gt

=head2 max => MAX

Require that the value is less or equal than some specified maximum.

Synonyms: le

=head2 maxex => MAX

Require that the value is less than some specified maximum.

Synonyms: lt

=head2 between => [MIN, MAX]

A convenient attribut to combine B<min> and B<max>.

=head1 AUTHOR

  Steven Haryanto <stevenharyanto@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2009 by Steven Haryanto.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

