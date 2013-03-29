package Data::Schema::Plugin::LoadSchema::Base;
our $VERSION = '0.136';


# ABSTRACT: Base class for other DSP::LoadSchema::* plugins

use Moose;
use Data::Schema::Type::Schema;


has 'validator' => (is => 'rw');

has 'met_types' => (is => 'rw');


sub BUILD {
    my ($self, $args) = @_;
    $self->met_types({}) unless $self->met_types;
}


sub get_schema {
    return;
}


sub handle_unknown_type {
    my ($self, $name) = @_;

    my $schema = $self->get_schema($name);
    return -1 unless defined($schema);

    my $prefix = "Error loading schema type `$name'";

    die "$prefix: Recursive/circular typing `$name'" if $self->met_types->{$name}++;

    my $s = $self->validator->normalize_schema($schema);
    die "$prefix: schema error: $s" unless ref($s);

    my $base_type = $s->{type};
    my @attr_hashes0 = @{ $s->{attr_hashes} };
    my $th = $self->validator->get_type_handler($base_type) or
        die "$prefix: unknown base type `$base_type'";
    if ($th->isa("Data::Schema::Type::Schema")) {
        $base_type = $th->nschema->{type};
        unshift @attr_hashes0, @{ $th->nschema->{attr_hashes} };
    }

    # merge attribute hashes
    my $res = $self->validator->merge_attr_hashes(\@attr_hashes0);
    die "$prefix: merge error: $res->{error}" if $res->{error};

    my $t = Data::Schema::Type::Schema->new(nschema=>$s, name=>$name);
    $self->validator->register_type($name => $t);
    1;
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;

__END__
=pod

=head1 NAME

Data::Schema::Plugin::LoadSchema::Base - Base class for other DSP::LoadSchema::* plugins

=head1 VERSION

version 0.136

=head1 SYNOPSIS

    # see other DSP::LoadSchema::* plugins

=head1 ATTRIBUTES

=head2 validator

=head1 METHODS

=head2 get_schema($self, $name)

Return the schema specified by C<$name>, or C<undef> if not found. Override this
in your subclass.

=head2 handle_unknown_type($name)

Load and register schema type if found, or -1 if not found.

=head1 AUTHOR

  Steven Haryanto <stevenharyanto@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2009 by Steven Haryanto.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

