package Data::Schema::Plugin::LoadSchema::Hash;
our $VERSION = '0.13';


# ABSTRACT: Plugin to load schemas from hashes

use Moose;
extends 'Data::Schema::Plugin::LoadSchema::Base';


sub get_schema {
    my ($self, $name) = @_;
    my $found;

    for my $h (@{ $self->validator->config->schema_search_path }) {
        next unless ref($h) eq 'HASH' && exists $h->{$name};
        return $h->{$name};
    }
    return;
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;

__END__
=pod

=head1 NAME

Data::Schema::Plugin::LoadSchema::Hash - Plugin to load schemas from hashes

=head1 VERSION

version 0.13

=head1 SYNOPSIS

    use Data::Schema;

    # schemas are located in hashes
    my $schemas = {
        even => [int=>{divisible_by=>2}],
    }

    my $ds = Data::Schema->new;
    $ds->register_plugin('Data::Schema::Plugin::LoadSchema::Hash');
    $ds->config->schema_search_path([$schemas]);

=head1 METHODS

=head2 get_schema($self, $name)

Get schema from hashes, or C<undef> if not found. List of hashes to search from
is specified in validator's C<schema_search_path> config variable.

=head1 AUTHOR

  Steven Haryanto <stevenharyanto@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2009 by Steven Haryanto.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

