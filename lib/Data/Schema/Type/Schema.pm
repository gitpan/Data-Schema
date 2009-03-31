package Data::Schema::Type::Schema;

=head1 NAME

Data::Schema::Type::Schema - Make schema as type

=head1 SYNOPSIS

    # write schemas and store them in hashes (or files, or objects, ...)
    my $schemas = {
        even_int => [int => {divisible_by=>2}],
        positive_even => [even_int => {min=>0}],
    };

    use Data::Schema;
    my $ds = Data::Schema->new(
        plugins=>['Data::Schema::Plugin::LoadSchema::Hash']
    );
    $n->config->schema_search_path([$schemas]);

    my $res;
    $res = $ds->validate(-2, 'even_int');                   # success
    $res = $ds->validate(-2, 'positive_even');              # fail
    $res = $ds->validate(4, [even_int=>{divisible_by=>3}]); # fail
    $res = $ds->validate(6, [even_int=>{divisible_by=>3}]); # success

=head1 DESCRIPTION

This is the type handler that makes a schema available as type in other
schemas. What this basically does is that you can reuse a schema in other
schemas.

See L<Data::Schema::Manual::Basics> for an explanation of schema as types.

To load schemas, either from a hash or YAML files, see
L<Data::Schema::Plugin::LoadSchema::Hash> or
L<Data::Schema::Plugin::LoadSchema::YAMLFile>.

=cut

use Moose;

has validator => (is => 'rw');

# normalized schema
has nschema => (is => 'rw');

sub handle_type {
    my ($self, $data, $attr_hashes) = @_;

    my $s = $self->nschema;
    my $ds = $self->validator;
    $ds->save_validation_state();
    $ds->init_validation_state();
    $ds->_validate($data, {
                           type=>$s->{type},
                           attr_hashes=>[@{$s->{attr_hashes}}, @$attr_hashes],
                           def=>$s->{def}});
    my $errors = $ds->errors;
    my $warnings = $ds->warnings;
    $ds->restore_validation_state();

    # push errors & warnings
    for (@$warnings) {
        if (@{ $ds->warnings } >= $ds->config->{max_warnings}) {
            $ds->too_many_warnings(1);
            last;
        }
        push @{ $ds->warnings },
            [[@{$ds->data_pos}, @{$_->[0]}], [@{$ds->schema_pos}, @{$_->[1]}], $_->[2]];
    }
    for (@$errors) {
        if (@{ $ds->errors } >= $ds->config->{max_errors}) {
            $ds->too_many_errors(1);
            last;
        }
        push @{ $ds->errors },
            [[@{$ds->data_pos}, @{$_->[0]}], [@{$ds->schema_pos}, @{$_->[1]}], $_->[2]];
    }

    !@$errors;
}

=head1 TYPE ATTRIBUTES

The type attributes available are whatever attributes are available for the base
type.

=head1 AUTHOR

Steven Haryanto, C<< <steven at masterweb.net> >>

=head1 COPYRIGHT & LICENSE

Copyright 2009 Steven Haryanto, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut

__PACKAGE__->meta->make_immutable;
1;
