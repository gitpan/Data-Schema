package Data::Schema::Type::Int;
our $VERSION = '0.132';


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


sub chkarg_attr_mod {
    my ($self, $arg, $name) = @_;
    my $ds = $self->validator;
    return unless $self->chkarg_r_array_of_int($arg, $name, 2, 2);
    if ($arg->[0] == 0) {
        $ds->schema_error("$name: illegal modulus zero");
        return;
    }
    1;
}

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


sub chkarg_attr_divisible_by {
    my ($self, $arg, $name) = @_;
    my $ds = $self->validator;
    if (!ref($arg)) {
        return unless $self->chkarg_r_int($arg, $name);
        if ($arg == 0) {
            $ds->schema_error("$name: illegal division by zero");
            return;
        }
    } elsif (ref($arg) eq 'ARRAY') {
        return unless $self->chkarg_r_array_of_int($arg, $name, 0, 0);
        for (@$arg) {
            if ($arg == 0) {
                $ds->schema_error("$name/$_: illegal division by zero");
                return;
            }
        }
    } else {
        $ds->schema_error("$name: must be int or array");
        return;
    }
    1;
}

sub handle_attr_divisible_by {
    my ($self, $data, $args) = @_;
    my $list = ref($args) eq 'ARRAY' ? $args : [$args];
    for (@$list) {
        if ($data % $_) {
            $self->validator->data_error("must be divisible by $_");
            return;
        }
    }
    1;
}

sub emitpl_attr_divisible_by {
    my ($self, $args) = @_;
    my $ds = $self->validator;
    my $perl = '';
    $perl .= $ds->emitpl_my('$arg');
    $perl .= '$arg = '.$self->_perl(ref($args) eq 'ARRAY' ? $args : [$args]).";\n";
    $perl .= 'for (@$arg) {'."\n";
    $perl .= '    if ($data % $_) { '.$self->validator->emitpl_data_error('"must be divisible by $_"', 1)." }\n";
    $perl .= "}\n";
    $perl;
}


sub chkarg_attr_not_divisible_by { chkarg_attr_divisible_by(@_) }

sub handle_attr_not_divisible_by {
    my ($self, $data, $args) = @_;
    my $list = ref($args) eq 'ARRAY' ? $args : [$args];
    for (@$list) {
        if ($data % $_ == 0) {
            $self->validator->data_error("must not be divisible by $_");
            return;
        }
    }
    1;
}

sub emitpl_attr_not_divisible_by {
    my ($self, $args) = @_;
    my $ds = $self->validator;
    my $perl = '';
    $perl .= $ds->emitpl_my('$arg');
    $perl .= '$arg = '.$self->_perl(ref($args) eq 'ARRAY' ? $args : [$args]).";\n";
    $perl .= 'for (@$arg) {'."\n";
    $perl .= '    if ($data % $_ == 0) { '.$self->validator->emitpl_data_error('"must be divisible by $_"', 1)." }\n";
    $perl .= "}\n";
    $perl;
}

Data::Schema::Type::Base::__make_attr_alias(not_divisible_by => qw/indivisible_by/);

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

version 0.132

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

=head2 divisible_by => INT or ARRAY

Require that data is divisible by all specified numbers.

Example:

 ds_validate( 4, [int=>{divisible_by=>2}]     ); # valid
 ds_validate( 4, [int=>{divisible_by=>[2,3]}] ); # invalid
 ds_validate( 6, [int=>{divisible_by=>[2,3]}] ); # valid

=head2 not_divisible_by => INT or ARRAY

Aliases: indivisible_by

Opposite of divisible_by.

=head1 AUTHOR

  Steven Haryanto <stevenharyanto@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2009 by Steven Haryanto.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

