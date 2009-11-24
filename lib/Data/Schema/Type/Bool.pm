package Data::Schema::Type::Bool;
our $VERSION = '0.12';


# ABSTRACT: Type handler for booleans ('bool')


use Moose;
extends 'Data::Schema::Type::Base';
with 'Data::Schema::Type::Scalar', 'Data::Schema::Type::Comparable', 'Data::Schema::Type::Sortable';

sub _equal {
    my ($self, $a, $b) = @_;
    (($a ? 1:0) <=> ($b ? 1:0)) == 0;
}

sub _emitpl_equal {
    my ($self, $a, $b) = @_;
    "(((($a) ? 1:0) <=> (($b) ? 1:0)) == 0)";
}

sub _compare {
    my ($self, $a, $b) = @_;
    ($a ? 1:0) <=> ($b ? 1:0);
    # true is considered larger than false
}

sub _emitpl_compare {
    my ($self, $a, $b) = @_;
    "((($a) ? 1:0) <=> (($b) ? 1:0))";
    # true is considered larger than false
}

override _dump => sub {
    my ($self, $val) = @_;
    $val ? "true" : "false";
};

override _emitpl_dump => sub {
    my ($self, $val) = @_;
    "(($val) ? 'true' : 'false')";
};

sub short_english {
    "bool";
}
    
sub english {
    "bool";
}


__PACKAGE__->meta->make_immutable;
no Moose;
1;

__END__
=pod

=head1 NAME

Data::Schema::Type::Bool - Type handler for booleans ('bool')

=head1 VERSION

version 0.12

=head1 SYNOPSIS

 use Data::Schema;

=head1 DESCRIPTION

This is the type handler for type 'bool'.

Synonyms: boolean

=head1 TYPE ATTRIBUTES

Bool is Scalar, Comparable and Sortable, so you might want to consult the
docs of those roles to see what type attributes are available.

=head1 AUTHOR

  Steven Haryanto <stevenharyanto@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2009 by Steven Haryanto.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

