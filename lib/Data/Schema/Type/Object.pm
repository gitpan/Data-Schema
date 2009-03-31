package Data::Schema::Type::Object;

=head1 NAME

Data::Schema::Type::Object - Type handler for Perl objects ('object')

=head1 SYNOPSIS

 use Data::Schema;

=head1 DESCRIPTION

You can validate Perl objects with this type handler.

Synonym: obj

Example schema (in YAML syntax):

 - object
 - can: [validate]

Example valid data:

 Data::Schema->new(); # can validate()

Example invalid data:

 IO::Handler->new(); # cannot validate()
 1;                  # is not a Perl object

=cut

use Moose;
extends 'Data::Schema::Type::Base';
use Scalar::Util 'blessed';

sub cmp {
    return undef; # XXX currently we don't provide comparison, maybe we should
}

sub handle_pre_check_attrs {
    my ($self, $data) = @_;
    if (!blessed($data)) {
        $self->validator->log_error("must be an object");
        return;
    }
    1;
}

=head1 TYPE ATTRIBUTES

=head2 can_one => (meth OR [meth, ...])

Requires that the object be able (UNIVERSAL::can) to do any one of the specified
methods.

=cut

sub handle_attr_can_one {
    my ($self, $data, $arg) = @_;
    my $methods = ref($arg) eq 'ARRAY' ? $arg : [$arg];

    unless (grep {$data->can($_)} @$methods) {
        my $msg;
        if (@$methods == 1) {
            $msg = "object must have ".$methods->[0]."() method";
        } elsif (@$methods <= 10) {
            $msg = "object must have one of these methods: ".join(", ", @$methods);
        } else {
            $msg = "object doesn't have any of the required methods";
        }
        $self->validator->log_error($msg);
        return 0;
    }
    1;
}

=head2 can_all => (meth OR [meth, ...])

Requires that the object be able (UNIVERSAL::can) to do all of the specified
methods.

Synonyms: can

=cut

sub handle_attr_can_all {
    my ($self, $data, $arg, $is_can) = @_;
    my $methods = ref($arg) eq 'ARRAY' ? $arg : [$arg];

    if (grep {!$data->can($_)} @$methods) {
        my $msg;
        if (@$methods == 1) {
            $msg = "object must have ".$methods->[0]."() method";
        } elsif (@$methods <= 10) {
            $msg = "object must have all of these methods: ".join(", ", @$methods);
        } else {
            $msg = "object doesn't have all of the required methods";
        }
        $self->validator->log_error($msg);
        return 0;
    }
    1;
}

# aliases
sub handle_attr_can { handle_attr_can_all(@_) }

=head2 cannot  => (meth OR [meth, ...])

Requires that the object not be able (UNIVERSAL::can) to do any of the specified
methods.

Synonyms: cant

=cut

sub handle_attr_cannot {
    my ($self, $data, $arg, $is_can) = @_;
    my $methods = ref($arg) eq 'ARRAY' ? $arg : [$arg];

    if (grep {$data->can($_)} @$methods) {
        my $msg;
        if (@$methods == 1) {
            $msg = "object must not have ".$methods->[0]."() method";
        } elsif (@$methods <= 10) {
            $msg = "object must not have any of these methods: ".join(", ", @$methods);
        } else {
            $msg = "object has one or more of the unwanted methods";
        }
        $self->validator->log_error($msg);
        return 0;
    }
    1;
}

sub handle_attr_cant { handle_attr_cannot(@_) }

=head2 isa_one => (class OR [class, ...])

Requires that the object be of (UNIVERSAL::isa) any one of the specified
classes.

=cut

sub handle_attr_isa_one {
    my ($self, $data, $arg) = @_;
    my $classes = ref($arg) eq 'ARRAY' ? $arg : [$arg];

    unless (grep {$data->isa($_)} @$classes) {
        my $msg;
        if (@$classes == 1) {
            $msg = "object must be isa (".$classes ->[0].")";
        } elsif (@$classes <= 10) {
            $msg = "object must be isa() one of these classes: ".join(", ", @$classes );
        } else {
            $msg = "object isn't isa() any of the specified classes";
        }
        $self->validator->log_error($msg);
        return 0;
    }
    1;
}

=head2 isa_all => (class OR [class, ...])

Requires that the object be of (UNIVERSAL::isa) all of the specified classes.

Synonyms: isa

=cut

sub handle_attr_isa_all {
    my ($self, $data, $arg) = @_;
    my $classes = ref($arg) eq 'ARRAY' ? $arg : [$arg];

    if (grep {!$data->isa($_)} @$classes) {
        my $msg;
        if (@$classes == 1) {
            $msg = "object must isa(".$classes->[0].")";
        } elsif (@$classes <= 10) {
            $msg = "object must isa() all of these classes: ".join(", ", @$classes);
        } else {
            $msg = "object is not isa() all of the required classes";
        }
        $self->validator->log_error($msg);
        return 0;
    }
    1;
}

# aliases
sub handle_attr_isa { handle_attr_isa_all(@_) }

=head2 not_isa => (class OR [class, ...])

Requires that the object not be of (UNIVERSAL::isa) any of the specified
classes.

=cut

sub handle_attr_not_isa {
    my ($self, $data, $arg) = @_;
    my $classes = ref($arg) eq 'ARRAY' ? $arg : [$arg];

    if (grep {$data->isa($_)} @$classes) {
        my $msg;
        if (@$classes == 1) {
            $msg = "object must not be isa(".$classes->[0].")";
        } elsif (@$classes <= 10) {
            $msg = "object must not be isa() any of these classes: ".join(", ", @$classes);
        } else {
            $msg = "object is isa() one or more of the unwanted classes";
        }
        $self->validator->log_error($msg);
        return 0;
    }
    1;
}

=head1 AUTHOR

Steven Haryanto, C<< <steven at masterweb.net> >>

=head1 COPYRIGHT & LICENSE

Copyright 2009 Steven Haryanto, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut

__PACKAGE__->meta->make_immutable;
1;
