package Data::Schema::Plugin::LoadSchema::Hash;

use Moose;
extends 'Data::Schema::Plugin::LoadSchema::Base';

=head1 NAME

Data::Schema::Plugin::LoadSchema::Hash - Plugin to load schemas from hashes

=head1 SYNOPSIS

    use Data::Schema;

    # schemas are located in hashes
    my $schemas = {
        even => [int=>{divisible_by=>2}],
    }

    my $ds = Data::Schema->new;
    $ds->register_plugin('Data::Schema::Plugin::LoadSchema::Hash');
    $ds->config->{'schema_search_path'} = [$schemas];

=head1 METHODS

=head2 get_schema($self, $name)

Get schema from hashes, or C<undef> if not found. List of hashes to search from
is specified in validator's C<schema_search_path> config variable.

=cut

sub get_schema {
    my ($self, $name) = @_;
    my $found;

    for my $h (@{ $self->validator->config->{schema_search_path} }) {
        next unless ref($h) eq 'HASH' && exists $h->{$name};
        return $h->{$name};
    }
    return;
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
