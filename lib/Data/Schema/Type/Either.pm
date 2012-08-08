package Data::Schema::Type::Either;
our $VERSION = '0.135';


# ABSTRACT: Type handler for 'either' type


use Moose;
extends 'Data::Schema::Type::Base';
with 'Data::Schema::Type::Scalar';


sub chkarg_attr_of {
    my ($self, $arg, $name) = @_;
    $self->chkarg_r_array_of_schema($arg, $name);
}

sub handle_attr_of {
    my ($self, $data, $arg) = @_;
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
    $ds->data_error("data does not validate to any alternatives");
    return 0;
}

sub emitpl_attr_of {
    my ($self, $arg) = @_;
    my $ds = $self->validator;
    my $perl = '';

    my @schemas;
    for my $i (0..@$arg-1) {
	my ($code, $csubname) = $ds->emitpls_sub($arg->[$i]);
	$perl .= $code;
	push @schemas, $csubname;
    }

    $perl .= $ds->emitpl_my('@schemas');
    $perl .= '@schemas = ('.join(", ", map { "\\&$_" } @schemas).");\n";
    $perl .= $ds->emitpl_my('$found');
    $perl .= '$found = 0;'."\n";
    $perl .= 'for my $i (0..@schemas-1) {'."\n";
    $perl .= '    my ($suberrors, $subwarnings) = $schemas[$i]($data);'."\n";
    $perl .= '    if (!@$suberrors) { $found++; last }'."\n";
    $perl .= "}\n";
    $perl .= 'if (!$found) { '.$ds->emitpl_data_error("data does not validate to any alternatives")." }\n";
    $perl;
}

sub short_english {
    "either";
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
                return join " or ", map { "($_)" } @e;
            }
        }
    }
    return "either";
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;

__END__
=pod

=head1 NAME

Data::Schema::Type::Either - Type handler for 'either' type

=head1 VERSION

version 0.135

=head1 SYNOPSIS

 use Data::Schema;

=head1 DESCRIPTION

Aliases: or, any

'Either' is not really an actual data type, but a way to validate whether a
value validates to any one of the specified schemas.

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

=head1 TYPE ATTRIBUTES

Either is Scalar, so you might want to consult the docs of those roles to
see what type attributes are available.

=head2 of => [schema1, schema2, ...]

Specify the schema(s), where the value will need to be valid to one of them.

=head1 AUTHOR

  Steven Haryanto <stevenharyanto@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2009 by Steven Haryanto.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

