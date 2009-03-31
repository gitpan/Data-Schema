package Data::Schema::Type::Either;

=head1 NAME

Data::Schema::Type::Either - Type handler for 'either' type

=head1 SYNOPSIS

 use Data::Schema;

=head1 DESCRIPTION

'Either' is not really an actual data type, but a way to validate whether a
value validates to any one of the specified schemas.

Synonym: or, any

Example schema (in YAML syntax):

 - any
 - of:
     - [int, {divisible_by: 2}]
     - [int, {divisible_by: 7}]

Example valid data:

 42  # divisible by 2 as well as 7

 21  # not divisible by 2 but divisible by 7

 4   # not divisible by 7 but divisible by 2

Example invalid data:

 15 # not divisible by 2 nor 7

=cut

use Moose;
extends 'Data::Schema::Type::Base';

sub cmp {
    return undef; # currently we don't provide comparison
}

=head1 TYPE ATTRIBUTES

=head2 alternatives => [schema1, schema2, ...]

Specify the schema(s), where the value will need to be valid to one of them.

Synonym: alternative, alt, alts, schema, schemas, choice, choices, of

=cut

sub handle_attr_alternatives {
    my ($self, $data, $arg) = @_;

    if (ref($arg) ne 'ARRAY') {
        $self->validator->log_error("schema error: alternatives must be arrayref");
        return;
    }

    my $ds = $self->validator;

    my $success;
    for my $i (0..@$arg-1) {
        $ds->save_validation_state();
        $ds->init_validation_state();
        $ds->_validate($data, $arg->[$i]);
        $success = !@{ $ds->errors };
        $ds->restore_validation_state();
        return 1 if $success;
    }
    $ds->log_error("data does not validate to any alternatives");
    return 0;
}

# aliases
sub handle_attr_alternative { handle_attr_alternatives(@_) }
sub handle_attr_alts { handle_attr_alternatives(@_) }
sub handle_attr_alt { handle_attr_alternatives(@_) }
sub handle_attr_schemas { handle_attr_alternatives(@_) }
sub handle_attr_schema { handle_attr_alternatives(@_) }
sub handle_attr_choices { handle_attr_alternatives(@_) }
sub handle_attr_choice { handle_attr_alternatives(@_) }
sub handle_attr_of { handle_attr_alternatives(@_) }

=head1 AUTHOR

Steven Haryanto, C<< <steven at masterweb.net> >>

=head1 COPYRIGHT & LICENSE

Copyright 2009 Steven Haryanto, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut

__PACKAGE__->meta->make_immutable;
1;
