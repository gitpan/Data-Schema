package Data::Schema::Plugin::LoadSchema::YAMLFile;
our $VERSION = '0.135';


# ABSTRACT: Plugin to load schemas from YAML files

use Moose;
use File::Slurp;
use YAML::Syck;

extends 'Data::Schema::Plugin::LoadSchema::Base';


sub get_schema {
    my ($self, $name) = @_;
    my $path;
    my $found;

    my $sp = $self->validator->config->schema_search_path;
    for my $dir (ref($sp) eq 'ARRAY' ? @$sp : $sp) {
        my $path0 = "$dir/$name";
        while (1) {
            $path = $path0;
            #print "DEBUG: YAMLFile: trying $path ...\n";
            (-f $path) and do { $found++; last };
            for my $ext (qw(yaml yml)) {
                $path = "$path0.$ext";
                #print "DEBUG: YAMLFile: trying $path ...\n";
                (-f $path) and do { $found++; last };
            }
            last;
        }
        last if $found;
    }

    if ($found) {
	#print "DEBUG: found YAML file $path, loading ...\n";
        my $content = read_file($path);
	($content) = $content =~ /(.*)/s; # untaint
	return Load($content);
    }
    return;
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;

__END__
=pod

=head1 NAME

Data::Schema::Plugin::LoadSchema::YAMLFile - Plugin to load schemas from YAML files

=head1 VERSION

version 0.135

=head1 SYNOPSIS

    # in schemadir/even_int.yaml
    - int
    - divisible_by: 2

    # in your code
    use Data::Schema;
    my $ds = Data::Schema->new;
    $ds->register_plugin('Data::Schema::Plugin::LoadSchema::YAMLFile');
    $ds->config->schema_search_path(["schemadir"]);

    my $res;
    $res = $ds->validate(2, 'even_int'); # success
    $res = $ds->validate(3, 'even_int'); # fails

=head1 METHODS

=head2 get_schema($self, $name)

Return schema loaded from YAML file, or C<undef> if not found. List of
directories to search for is specified in validator's C<schema_search_path>
config variable. "$name", "$name.{yaml,yml}" files will be searched for.

=head1 AUTHOR

  Steven Haryanto <stevenharyanto@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2009 by Steven Haryanto.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

