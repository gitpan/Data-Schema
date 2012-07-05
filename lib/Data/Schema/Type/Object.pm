package Data::Schema::Type::Object;
our $VERSION = '0.134';


# ABSTRACT: Type handler for Perl objects ('object')


use Moose;
extends 'Data::Schema::Type::Base';
with 'Data::Schema::Type::Scalar';
use Scalar::Util 'blessed';

sub handle_pre_check_attrs {
    my ($self, $data) = @_;
    if (!blessed($data)) {
        $self->validator->data_error("must be an object");
        return;
    }
    1;
}

sub emitpl_pre_check_attrs {
    my ($self) = @_;
    my $perl = '';

    $perl .= $self->validator->emitpl_require("Scalar::Util");
    $perl .= 'if (!Scalar::Util::blessed($data)) { '.$self->validator->emitpl_data_error("must be an object").'; pop @$schemapos; last L1 }'."\n";
    $perl;
}


sub chkarg_attr_can_one {
    my ($self, $arg, $name) = @_;
    $self->chkarg_r_str_or_array_of_str($arg, $name);
}

sub handle_attr_can_one {
    my ($self, $data, $arg) = @_;
    my $methods = ref($arg) eq 'ARRAY' ? $arg : [$arg];

    unless (grep {$data->can($_)} @$methods) {
        $self->validator->data_error("object must have one of these methods: ".join(", ", @$methods));
        return 0;
    }
    1;
}

sub emitpl_attr_can_one {
    my ($self, $arg) = @_;
    my $ds = $self->validator;
    my $perl = '';

    $perl .= $ds->emitpl_my('$methods');
    $perl .= '$methods = '.$self->_perl(ref($arg) eq 'ARRAY' ? $arg : [$arg]).";\n";
    $perl .= 'unless (grep {$data->can($_)} @$methods) {'."\n";
    $perl .= '    '.$ds->emitpl_data_error('"object must have one of these methods: ".join(", ", @$methods)', 1). "}\n";
    $perl;
}


sub chkarg_attr_can_all { chkarg_attr_can_one(@_) }

sub handle_attr_can_all {
    my ($self, $data, $arg, $is_can) = @_;
    my $methods = ref($arg) eq 'ARRAY' ? $arg : [$arg];

    if (grep {!$data->can($_)} @$methods) {
        $self->validator->data_error("object must have all of these methods: ".join(", ", @$methods));
        return 0;
    }
    1;
}

sub emitpl_attr_can_all {
    my ($self, $arg) = @_;
    my $ds = $self->validator;
    my $perl = '';

    $perl .= $ds->emitpl_my('$methods');
    $perl .= '$methods = '.$self->_perl(ref($arg) eq 'ARRAY' ? $arg : [$arg]).";\n";
    $perl .= 'if (grep {!$data->can($_)} @$methods) {'."\n";
    $perl .= '    '.$ds->emitpl_data_error('"object must have all of these methods: ".join(", ", @$methods)', 1). "}\n";
    $perl;
}

Data::Schema::Type::Base::__make_attr_alias(can_all => qw/can/);


sub chkarg_attr_cannot { chkarg_attr_can_one(@_) }

sub handle_attr_cannot {
    my ($self, $data, $arg, $is_can) = @_;
    my $methods = ref($arg) eq 'ARRAY' ? $arg : [$arg];

    if (grep {$data->can($_)} @$methods) {
        $self->validator->data_error("object must not have any of these methods: ".join(", ", @$methods));
        return 0;
    }
    1;
}

sub emitpl_attr_cannot {
    my ($self, $arg) = @_;
    my $ds = $self->validator;
    my $perl = '';

    $perl .= $ds->emitpl_my('$methods');
    $perl .= '$methods = '.$self->_perl(ref($arg) eq 'ARRAY' ? $arg : [$arg]).";\n";
    $perl .= 'if (grep {$data->can($_)} @$methods) {'."\n";
    $perl .= '    '.$ds->emitpl_data_error('"object must not have any of these methods: ".join(", ", @$methods)', 1). "}\n";
    $perl;
}

Data::Schema::Type::Base::__make_attr_alias(cannot => qw/cant/);


sub chkarg_attr_isa_one {
    my ($self, $arg, $name) = @_;
    $self->chkarg_r_str_or_array_of_str($arg, $name);
}

sub handle_attr_isa_one {
    my ($self, $data, $arg) = @_;
    my $classes = ref($arg) eq 'ARRAY' ? $arg : [$arg];

    unless (grep {$data->isa($_)} @$classes) {
        $self->validator->data_error("object must belong to one of these classes : ".join(", ", @$classes));
        return 0;
    }
    1;
}

sub emitpl_attr_isa_one {
    my ($self, $arg) = @_;
    my $ds = $self->validator;
    my $perl = '';

    $perl .= $ds->emitpl_my('$classes');
    $perl .= '$classes = '.$self->_perl(ref($arg) eq 'ARRAY' ? $arg : [$arg]).";\n";
    $perl .= 'unless (grep {$data->isa($_)} @$classes) {'."\n";
    $perl .= '    '.$ds->emitpl_data_error('"object must belong to any of these classes: ".join(", ", @$classes)', 1). "}\n";
    $perl;
}


sub chkarg_attr_isa_all { chkarg_attr_isa_one(@_) }

sub handle_attr_isa_all {
    my ($self, $data, $arg) = @_;
    my $classes = ref($arg) eq 'ARRAY' ? $arg : [$arg];

    if (grep {!$data->isa($_)} @$classes) {
        $self->validator->data_error("object must belong to all of these classes : ".join(", ", @$classes));
        return 0;
    }
    1;
}

sub emitpl_attr_isa_all {
    my ($self, $arg) = @_;
    my $ds = $self->validator;
    my $perl = '';

    $perl .= $ds->emitpl_my('$classes');
    $perl .= '$classes = '.$self->_perl(ref($arg) eq 'ARRAY' ? $arg : [$arg]).";\n";
    $perl .= 'if (grep {!$data->isa($_)} @$classes) {'."\n";
    $perl .= '    '.$ds->emitpl_data_error('"object must belong to all of these classes: ".join(", ", @$classes)', 1). "}\n";
    $perl;
}

Data::Schema::Type::Base::__make_attr_alias(isa_all => qw/isa/);


sub chkarg_attr_not_isa { chkarg_attr_isa_one(@_) }

sub handle_attr_not_isa {
    my ($self, $data, $arg) = @_;
    my $classes = ref($arg) eq 'ARRAY' ? $arg : [$arg];

    if (grep {$data->isa($_)} @$classes) {
        $self->validator->data_error("object must not belong to any of these classes : ".join(", ", @$classes));
        return 0;
    }
    1;
}

sub emitpl_attr_not_isa {
    my ($self, $arg) = @_;
    my $ds = $self->validator;
    my $perl = '';

    $perl .= $ds->emitpl_my('$classes');
    $perl .= '$classes = '.$self->_perl(ref($arg) eq 'ARRAY' ? $arg : [$arg]).";\n";
    $perl .= 'if (grep {$data->isa($_)} @$classes) {'."\n";
    $perl .= '    '.$ds->emitpl_data_error('"object must not belong to any of these classes: ".join(", ", @$classes)', 1). "}\n";
    $perl;
}

sub short_english {
    "object";
}

sub english {
    "object";
    # XXX isa_one, isa_all, can_one, can_all
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;

__END__
=pod

=head1 NAME

Data::Schema::Type::Object - Type handler for Perl objects ('object')

=head1 VERSION

version 0.134

=head1 SYNOPSIS

 use Data::Schema;

=head1 DESCRIPTION

Aliases: obj

You can validate Perl objects with this type handler.

Example schema (in YAML syntax):

 - object
 - can: [validate]

Example valid data:

 Data::Schema->new(); # can validate()

Example invalid data:

 IO::Handler->new(); # cannot validate()
 1;                  # is not a Perl object

=head1 TYPE ATTRIBUTES

Object is Scalar, so you might want to consult the docs of those roles to
see what type attributes are available.

=head2 can_one => (meth OR [meth, ...])

Requires that the object be able (UNIVERSAL::can) to do any one of the specified
methods.

=head2 can_all => (meth OR [meth, ...])

Aliases: can

Requires that the object be able (UNIVERSAL::can) to do all of the specified
methods.

=head2 cannot  => (meth OR [meth, ...])

Aliases: cant

Requires that the object not be able (UNIVERSAL::can) to do any of the specified
methods.

=head2 isa_one => (class OR [class, ...])

Requires that the object be of (UNIVERSAL::isa) any one of the specified
classes.

=head2 isa_all => (class OR [class, ...])

Aliases: isa

Requires that the object be of (UNIVERSAL::isa) all of the specified classes.

=head2 not_isa => (class OR [class, ...])

Requires that the object not be of (UNIVERSAL::isa) any of the specified
classes.

=head1 AUTHOR

  Steven Haryanto <stevenharyanto@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2009 by Steven Haryanto.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

