package Data::Schema::Type::Num;
our $VERSION = '0.132';


# ABSTRACT: Base type handler for numbers


use Moose;
extends 'Data::Schema::Type::Base';
with 'Data::Schema::Type::Scalar', 'Data::Schema::Type::Comparable', 'Data::Schema::Type::Sortable';
use Scalar::Util qw/looks_like_number/;

sub _equal {
    my ($self, $a, $b) = @_;
    ($a == $b);
}

sub _emitpl_equal {
    my ($self, $a, $b) = @_;
    "(($a) == ($b))";
}

sub _compare {
    my ($self, $a, $b) = @_;
    $a <=> $b;
}

sub _emitpl_compare {
    my ($self, $a, $b) = @_;
    "(($a) <=> ($b))";
}

sub handle_pre_check_attrs {
    my ($self, $data) = @_;
    if (!looks_like_number($data)) {
        $self->validator->data_error("data not a number");
        return;
    }
    1;
}

sub emitpl_pre_check_attrs {
    my ($self) = @_;
    my $perl = '';

    $perl .= $self->validator->emitpl_require("Scalar::Util");
    $perl .= 'if (!Scalar::Util::looks_like_number($data)) { '.$self->validator->emitpl_data_error("data not a number").'; pop @$schemapos; last L1 }'."\n";
    $perl;
}

sub short_english {
    "number";
}

sub english {
    "number";
}


__PACKAGE__->meta->make_immutable;
no Moose;
1;

__END__
=pod

=head1 NAME

Data::Schema::Type::Num - Base type handler for numbers

=head1 VERSION

version 0.132

=head1 SYNOPSIS

 # see subclasses, like DST::Int or DST::Float

=head1 DESCRIPTION

This is base class for number types, like 'int' and 'float'.

=head1 TYPE ATTRIBUTES

Numbers are Scalar, Comparable and Sortable, so you might want to consult
the docs of those roles to see what type attributes are available.

=head1 AUTHOR

  Steven Haryanto <stevenharyanto@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2009 by Steven Haryanto.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

