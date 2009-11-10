package Data::Schema::Type::All;

=head1 NAME

Data::Schema::Type::All - Type handler for 'all' type

=head1 SYNOPSIS

 use Data::Schema;

=head1 DESCRIPTION

'All' is not really an actual data type, but a way to validate whether a
value validates to all of the specified schemas. 'And' is another name for this
type.

Example schema (in YAML syntax):

 - all
 - schemas:
     - [int, {divisible_by: 2}]
     - [int, {divisible_by: 7}]

Example valid data:

 42  # divisible by 2 as well as 7

Example invalid data:

 21  # divisible by 7 but not by 2

 4   # divisible by 2 but not by 7

 15  # not divisible by 2 nor 7

=cut

use Moose;
extends 'Data::Schema::Type::Base';

sub cmp {
    return undef; # currently we don't provide comparison
}

sub english {
    my ($self, $schema, $opt) = @_;
    $schema = $self->validator->normalize_schema($schema)
        unless ref($schema) eq 'HASH';

    if (@{ $schema->{attr_hashes} }) {
        for my $alias (qw/of/) {
            my $of = $schema->{attr_hashes}[0]{$alias};
            if ($of && @$of) {
                my @e;
                for my $ss (@$of) {
                    $ss = $self->validator->normalize_schema($ss)
                        unless ref($ss) eq 'HASH';
                    my $th = $self->validator->get_type_handler($ss->{type});
                    push @e, $th->english($ss, $opt);
                }
                return join " as well as ", map { "($_)" } @e;
            }
        }
    }
    return "all";
}

=head1 TYPE ATTRIBUTES

=head2 of => [schema1, schema2, ...]

Specify the schema(s), where the value will need to be valid to all of them.

=cut

sub handle_attr_of {
    my ($self, $data, $arg) = @_;

    if (ref($arg) ne 'ARRAY') {
        $self->validator->log_error("schema error: schemas must be arrayref");
        return;
    }

    my $ds = $self->validator;

    my $has_err;
    for my $i (0..@$arg-1) {
        $ds->save_validation_state();
        $ds->init_validation_state();
        $ds->_validate($data, $arg->[$i]);
        my $fail = @{ $ds->errors };
        $ds->restore_validation_state();
        if ($fail) {
            $has_err++;
            $ds->log_error("data does not validate to schema#$i");
            return if $ds->too_many_errors;
        }
    }
    !$has_err;
}

=head1 AUTHOR

Steven Haryanto, C<< <steven at masterweb.net> >>

=head1 COPYRIGHT & LICENSE

Copyright 2009 Steven Haryanto, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut

__PACKAGE__->meta->make_immutable;
no Moose;
1;
