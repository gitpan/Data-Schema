package Data::Schema::Type::Int;
our $VERSION = '0.12';


# ABSTRACT: Type handler for integer numbers ('int')


use Moose;
extends 'Data::Schema::Type::Num';

override handle_pre_check_attrs => sub {
    return unless super(@_);
    my ($self, $data) = @_;
    if ($data != int($data)) {
        $self->validator->data_error("not an integer");
        return;
    }
    1;
};

override emitpl_pre_check_attrs => sub {
    my ($self) = @_;
    my $perl = super(@_);
    $perl .= 'if ($data != int($data)) { '.$self->validator->emitpl_data_error("not an integer").'; pop @$schemapos; last L1 }'."\n";
    $perl;
};


sub handle_attr_mod {
    my ($self, $data, $args) = @_;

    if (($data % $args->[0]) != $args->[1]) {
        $self->validator->data_error("data mod $args->[0] must be $args->[1]");
        return;
    }
    1;
}

sub emitpl_attr_mod {
    my ($self, $args) = @_;
    'if (($data % '.$args->[0].') != '.$args->[1].') { '.$self->validator->emitpl_data_error("data mod $args->[0] must be $args->[1]")." }\n";
}


sub handle_attr_divisible_by {
    my ($self, $data, $args) = @_;
    if ($data % $args) {
        $self->validator->data_error("must be divisible by $args");
        return;
    }
    1;
}

sub emitpl_attr_divisible_by {
    my ($self, $args) = @_;
    'if ($data % '.$args.') { '.$self->validator->emitpl_data_error("must be divisible by $args")." }\n";
}


sub handle_attr_not_divisible_by {
    my ($self, $data, $args) = @_;
    if ($data % $args == 0) {
        $self->validator->data_error("must not be divisible by $args");
        return;
    }
    1;
}

sub emitpl_attr_not_divisible_by {
    my ($self, $args) = @_;
    'if ($data % '.$args.' == 0) { '.$self->validator->emitpl_data_error("must not be divisible by $args")." }\n";
}

# aliases
sub handle_attr_indivisible_by { handle_attr_not_divisible_by(@_) }
sub emitpl_attr_indivisible_by { emitpl_attr_not_divisible_by(@_) }

sub short_english {
    "int";
}

sub english {
    "int";
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;

__END__
=pod

=head1 NAME

Data::Schema::Type::Int - Type handler for integer numbers ('int')

=head1 VERSION

version 0.12

=head1 SYNOPSIS

 use Data::Schema;

=head1 DESCRIPTION

This is the type handler for type 'int'.

=head1 TYPE ATTRIBUTES

See L<Data::Schema::Type::Num>.

In addition to those provided by Num, ints have additional attributes.

=head2 mod => [X, Y]

Require that (data mod X) equals Y. For example, mod => [2, 1]
effectively specifies odd numbers.

=head2 divisible_by => X

Require that (data mod X) equals 0.

=head2 not_divisible_by => X

Require that (data mod X) not equals 0.

Synonyms: indivisible_by

=head1 AUTHOR

  Steven Haryanto <stevenharyanto@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2009 by Steven Haryanto.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

