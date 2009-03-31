package Data::Schema::Plugin::LoadSchema::YAMLFile;

use Moose;
use File::Slurp;
use YAML::XS;

extends 'Data::Schema::Plugin::LoadSchema::Base';

=head1 NAME

Data::Schema::Plugin::LoadSchema::YAMLFile - Plugin to load schemas from YAML files

=head1 SYNOPSIS

    # in schemadir/even_int.yaml
    - int
    - divisible_by: 2

    # in your code
    use Data::Schema;
    my $ds = Data::Schema->new;
    $ds->register_plugin('Data::Schema::Plugin::LoadSchema::YAMLFile');
    $ds->config->{'schema_search_path'} = ["schemadir"];

    my $res;
    $res = $ds->validate(2, 'even_int'); # success
    $res = $ds->validate(3, 'even_int'); # fails

=head1 METHODS

=head2 get_schema($self, $name)

Return schema loaded from YAML file, or C<undef> if not found. List of
directories to search for is specified in validator's C<schema_search_path>
config variable. "$name", "$name.{schema,sn,yaml,yml}" files will be searched
for.

=cut

sub get_schema {
    my ($self, $name) = @_;
    my $path;
    my $found;

    my $sp = $self->validator->config->{schema_search_path};
    for my $dir (ref($sp) eq 'ARRAY' ? @$sp : $sp) {
        my $path0 = "$dir/$name";
        while (1) {
            $path = $path0;
            #print "searching for $path ...\n";
            (-f $path) and do { $found++; last };
            for my $ext (qw(schema sn yaml yml)) {
                $path = "$path0.$ext";
                #print "searching for $path ...\n";
                (-f $path) and do { $found++; last };
            }
            last;
        }
        last if $found;
    }

    if ($found) {
        return Load(scalar read_file($path));
        return 1;
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
