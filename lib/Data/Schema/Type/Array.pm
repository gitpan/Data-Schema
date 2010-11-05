package Data::Schema::Type::Array;
our $VERSION = '0.133';


# ABSTRACT: Type handler for arrays ('array')


use Moose;
extends 'Data::Schema::Type::Base';
with 
    'Data::Schema::Type::Comparable',
    'Data::Schema::Type::Scalar', # for 'deps' only actually
    'Data::Schema::Type::HasElement';
use Storable qw/freeze/;
use List::MoreUtils qw/uniq/;

# note: for small arrays (1-10 elements), Data::Compare is about 3x
# slower, Array::Compare is 2x faster but can only compare array of
# scalars. as the array grows larger (10-100), DC is getting even
# slower (up to 20x slower), and freeze+freeze is becoming comparable
# to AC. so freeze is the best compromise.
sub _equal {
    my ($self, $a, $b) = @_;
    ((ref($a) ? freeze($a) : $a) eq (ref($b) ? freeze($b) : $b));
}

sub _emitpl_equal {
    my ($self, $a, $b) = @_;
    "((ref($a) ? Storable::freeze($a) : $a) eq (ref($b) ? Storable::freeze($b) : $b))";
}

sub _length {
    my ($self, $data) = @_;
    scalar @$data;
}

sub _emitpl_length {
    my ($self, $data) = @_;
    '(scalar @'.$data.')';
}

sub _element {
    my ($self, $data, $idx) = @_;
    $data->[$idx];
}

sub _emitpl_element {
    my ($self, $data, $idx, $lit) = @_;
    '('.$data."->[".($lit ? $idx : $self->_dump($idx))."])";
}

sub _indexes {
    my ($self, $data) = @_;
    0..((scalar @$data)-1);
}

sub _emitpl_indexes {
    my ($self, $data) = @_;
    '(0..(scalar @{ '.$data.' })-1)';
}

sub handle_pre_check_attrs {
    my ($self, $data) = @_;
    if (ref($data) ne 'ARRAY') {
        $self->validator->data_error("must be an array");
        return;
    }
    1;
}

sub emitpl_pre_check_attrs {
    my ($self) = @_;
    my $perl = '';

    $perl .= $self->validator->emitpl_require("Storable", "List::MoreUtils");
    $perl .= 'if (ref($data) ne "ARRAY") { '.$self->validator->emitpl_data_error("must be an array").'; pop @$schemapos; last L1 }'."\n";
    $perl;
}


sub chkarg_attr_unique {
    my ($self, $arg, $name) = @_;
    $self->chkarg_r_bool($arg, $name);
}

sub handle_attr_unique {
    my ($self, $data, $arg) = @_;
    my $unique = !(@$data > uniq(@$data));
    if (($arg ? 1:0) xor ($unique ? 1:0)) {
        $self->validator->data_error("array must ".($arg ? "":"not ")."be unique");
        return;
    }
    1;
}

sub emitpl_attr_unique {
    my ($self, $arg) = @_;
    'if ('.($arg ? 1:0).' xor (@$data == List::MoreUtils::uniq(@$data))) { '.$self->validator->emitpl_data_error("array must ".($arg ? "":"not ")."be unique")." }\n";
}


sub chkarg_attr_elements {
    my ($self, $arg, $name) = @_;
    $self->chkarg_r_array_of_schema($arg, $name);
}

sub handle_attr_elements {
    my ($self, $data, $arg) = @_;
    my $has_err = 0;

    push @{ $self->validator->data_pos   }, 0;
    push @{ $self->validator->schema_pos }, "";
    for my $i (0..@$arg-1) {
        $self->validator->data_pos  ->[-1] = $i;
        $self->validator->schema_pos->[-1] = $i;
        if (!$self->validator->_validate($data->[$i], $arg->[$i])) {
            $has_err++;
        }
        last if $self->validator->too_many_errors;
    }
    pop @{ $self->validator->data_pos };
    pop @{ $self->validator->schema_pos };
    !$has_err;
}

sub emitpl_attr_elements {
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
    $perl .= 'push @$datapos, -1;'."\n";
    $perl .= 'push @$schemapos, "";'."\n";
    $perl .= 'for my $i (0..$#schemas) {'."\n";
    $perl .= '    $datapos  ->[-1] = $i;'."\n";
    $perl .= '    $schemapos->[-1] = $i;'."\n";
    $perl .= '    my ($suberrors, $subwarnings) = $schemas[$i]($data->[$i], $datapos, $schemapos);'."\n";
    $perl .= '    '.$ds->emitpl_push_errwarn();
    $perl .= "}\n";
    $perl .= 'pop @$datapos;'."\n";
    $perl .= 'pop @$schemapos;'."\n";
    $perl;
}

Data::Schema::Type::Base::__make_attr_alias(elements => qw/element elems elem/);


Data::Schema::Type::Base::__make_attr_alias(all_elements => qw/of/);


sub chkarg_attr_some_of {
    my ($self, $arg, $name) = @_;
    $self->chkarg_r_array($arg, $name, 0, 0,
                          sub {
                              my ($arg, $name) = @_;
                              return unless $self->chkarg_r_array($arg, $name, 3, 3);
                              return unless $self->chkarg_r_schema($arg->[0], "$name/0");
                              return unless $self->chkarg_r_int($arg->[1], "$name/1");
                              return unless $self->chkarg_r_int($arg->[2], "$name/2");
                              1;
                          }
                      );
}

sub handle_attr_some_of {
    my ($self, $data, $arg) = @_;
    my @num_valid = map {0} 1..@$arg;
    my $ds = $self->validator;

    $ds->save_validation_state();
    my $j = 0;
    for my $r (@$arg) {
        for my $i (0..@$data-1) {
            $ds->init_validation_state();
            $ds->_validate($data->[$i], $r->[0]);
            $num_valid[$j]++ unless @{ $ds->errors };
        }
        $j++;
    }
    $ds->restore_validation_state();

    my $has_err = 0;
    push @{ $ds->schema_pos }, 0;
    $j = 0;
    for my $r (@$arg) {
        $ds->schema_pos->[-1] = $j;
        my $m = $num_valid[$j];
        my $a = $r->[1];
        my $b = $r->[2];
        if ($a != -1 && $m < $a) {
            my $x = !ref($r->[0]) ? $r->[0] : ref($r->[0]) eq 'ARRAY' ? "[$r->[0][0] => ...]" : "{type=>$r->[0]{type}, ...}";
            $ds->data_error("array must contain at least $a elements of type $x");
            $has_err++;
            last if $ds->too_many_errors;
        }
        if ($b != -1 && $m > $b) {
            my $x = !ref($r->[0]) ? $r->[0] : ref($r->[0]) eq 'ARRAY' ? "[$r->[0][0] => ...]" : "{type=>$r->[0]{type}, ...}";
            $ds->data_error("array must contain at most $b elements of type $x");
            $has_err++;
            last if $ds->too_many_errors;
        }
        $j++;
    }
    pop @{ $ds->schema_pos };

    !$has_err;
}

sub emitpl_attr_some_of {
    my ($self, $arg) = @_;
    my $perl = '';
    my $ds = $self->validator;

    my @arg;
    for my $i ((0..@$arg-1)) {
	my $sch = $arg->[$i][0];
	my $tstr = !ref($sch) ? $sch : ref($sch) eq "ARRAY" ? "($sch->[0], ...)" : "($sch->{type}, ...)";
	my ($code, $csubname) = $ds->emitpls_sub($sch);
	$perl .= $code;
	push @arg, [$csubname, $arg->[$i][1]+0, $arg->[$i][2]+0, $tstr];
    }

    $perl .= $self->validator->emitpl_my('@arg');
    $perl .= '@arg = ('.join(", ", map {"[\\&$_->[0], $_->[1], $_->[2], '$_->[3]']"} @arg).");\n";
    $perl .= $self->validator->emitpl_my('@num_valid');
    $perl .= '@num_valid = map {0} 1..@arg;'."\n";

    $perl .= $self->validator->emitpl_my('$j');
    $perl .= '$j=0;'."\n";
    $perl .= 'for my $r (@arg) {'."\n";
    $perl .= '    for my $i (0..@$data-1) {'."\n";
    $perl .= '        my ($suberrors, $subwarnings) = $r->[0]($data->[$i]);'."\n";
    $perl .= '        if (!@$suberrors) { $num_valid[$j]++ }'."\n";
    $perl .= '    }'."\n";
    $perl .= '    $j++;'."\n";
    $perl .= '}'."\n";
    #$perl .= 'print Data::Dumper::Dumper(\@num_valid);'."\n";

    $perl .= '$j=0;'."\n";
    $perl .= 'push @$schemapos, -1;'."\n";
    $perl .= 'for my $r (@arg) {'."\n";
    $perl .= '    $schemapos->[-1] = $j;'."\n";
    $perl .= '    my ($t, $a, $b, $m) = ($r->[3], $r->[1], $r->[2], $num_valid[$j]);'."\n";
    $perl .= '    my $err = ($a != -1 && $m < $a) ? "at least $a" : ($b != -1 && $m > $b) ? "at most $b" : "";'."\n";
    $perl .= '    if ($err) {'."\n";
    $perl .= '    '.$self->validator->emitpl_data_error('"array must contain $err elements of type $t"', 1)."\n";
    $perl .= "    }\n";
    $perl .= '    $j++;'."\n";
    $perl .= "}\n";
    $perl .= 'pop @$schemapos;'."\n";
    $perl;
}


sub chkarg_attr_elements_regex {
    my ($self, $arg, $name) = @_;
    $self->chkarg_r_hash($arg, $name, 0, 0,
                         sub {
                             my ($arg, $name) = @_;
                             $self->chkarg_r_regex($arg, $name);
                         },
                         sub {
                             my ($arg, $name) = @_;
                             $self->chkarg_r_schema($arg, $name);
                         },
                     );
}

sub handle_attr_elements_regex {
    my ($self, $data, $arg) = @_;
    my $has_err = 0;

    push @{ $self->validator->data_pos }, 0;
    for my $i (0..@$data-1) {
        $self->validator->data_pos->[-1] = $i;
        for my $ks (keys %$arg) {
            next unless $i =~ qr/$ks/;
            push @{ $self->validator->schema_pos }, $ks;
            if (!$self->validator->_validate($data->[$i], $arg->{$ks})) {
                $has_err++;
            }
            pop @{ $self->validator->schema_pos };
            last if $self->validator->too_many_errors;
        }
        last if $self->validator->too_many_errors;
    }
    pop @{ $self->validator->data_pos };
    !$has_err;
}

sub emitpl_attr_elements_regex {
    my ($self, $arg) = @_;
    my $perl = '';
    my $ds = $self->validator;

    my @arg;
    for my $re (keys %$arg) {
	my $sch = $arg->{$re};
	my ($code, $csubname) = $ds->emitpls_sub($sch);
	$perl .= $code;
	push @arg, [qr/$re/, $csubname];
    }

    $perl .= $ds->emitpl_my('@arg');
    $perl .= '@arg = ('.join(", ", map {"[".$self->_dump($_->[0]).", \\&$_->[1]]"} @arg).");\n";

    $perl .= 'push @$datapos, -1;'."\n";
    $perl .= 'push @$schemapos, "";'."\n";
    $perl .= 'for my $i (0..@$data-1) {'."\n";
    $perl .= '    $datapos->[-1] = $i;'."\n";
    $perl .= '    for my $r (@arg) {'."\n";
    $perl .= '        $schemapos->[-1] = $r->[0];'."\n";
    $perl .= '        next unless $i =~ qr/$r->[0]/;'."\n";
    $perl .= '        my ($suberrors, $subwarnings) = $r->[1]($data->[$i], $datapos, $schemapos);'."\n";
    $perl .= '        '.$ds->emitpl_push_errwarn();
    $perl .= '    }'."\n";
    $perl .= '}'."\n";
    $perl .= 'pop @$datapos;'."\n";
    $perl .= 'pop @$schemapos;'."\n";
    $perl;
}

Data::Schema::Type::Base::__make_attr_alias(elements_regex => qw/element_regex elems_regex elem_regex/);

sub short_english {
    "array";
}

sub english {
    my ($self, $schema, $opt) = @_;
    $schema = $self->validator->normalize_schema($schema)
        unless ref($schema) eq 'HASH';

    if (@{ $schema->{attr_hashes} }) {
        for my $alias (qw/all_elements all_element all_elems all_elem of/) {
            my $of = $schema->{attr_hashes}[0]{$alias};
            next unless $of;
            $of = $self->validator->normalize_schema($of) unless ref($of) eq 'HASH';
            my $th;
            $th = $self->validator->get_type_handler($of->{type});
            my $e = $th->english($of, $opt);
            return "array of ($e)";
        }
    }
    return "array";
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;

__END__
=pod

=head1 NAME

Data::Schema::Type::Array - Type handler for arrays ('array')

=head1 VERSION

version 0.133

=head1 SYNOPSIS

 use Data::Schema;

=head1 DESCRIPTION

This is the handler for arrays (or arrayrefs, to be exact).

Example schema (in YAML syntax):

 [array, { minlen: 1, maxlen: 3, elem_regex: {'.*': int} }]

The above schema says that the array must have one to three elements, and all
elements must be integers.

Example valid data:

 [1, 2]

Example invalid data:

 []          # too short
 [1,2,3,4]   # too long
 ['x']       # element not integer

=head1 TYPE ATTRIBUTES

Arrays are Comparable and HasElement, so you can consult the docs for those
roles for available attributes. In addition to these, there are other attributes
for 'array':

=head2 unique => 0 or 1

If unique is 1, require that the array values be unique (like in a set). If
unique is 0, require that there are duplicates in the array.

Note: currently the implementation uses List::MoreUtils' uniq().

=head2 elements => [SCHEMA_FOR_FIRST_ELEMENT, SCHEMA_FOR_SECOND_ELEM, ...]

Aliases: element, elems, elem

Requires that each element of the array validates to the specified schemas.

Example (in YAML):

 [array, {elements: [ int, str, [int, {min: 0}] ]}]

The above example states that the array must have an int as the first element,
string as the second, and positive integer as the third.

=head2 of => SCHEMA

Aliases: all_elements, all_elems, all_elem

Requires that every element of the array validates to the specified schema.

=head2 some_of => [[TYPE, MIN, MAX], [TYPE, MIN, MAX], ...]

Requires that some elements be of certain type. TYPE is the name of the type,
MIN and MAX are numbers, -1 means unlimited.

Example (in YAML):

 [array, {some_of: [ [int, 1, -1], [str, 3, 3], [float, 0, 1] ]}]

The above requires that the array contains at least one integer, exactly three
strings, and at most one floating number.

=head2 elements_regex => {REGEX=>SCHEMA, REGEX2=>SCHEMA2, ...]

Aliases: element_regex, elems_regex, elem_regex

Similar to B<elements>, but instead of specifying schema for each
element, this attribute allows us to specify using regexes which elements we
want to specify schema for.

Example (in YAML):

 - array
 - elements_regex:
     '[02468]$': [int, {minex: 0}]
     '[13579]$': [int, {maxex: 0}]

The above example states that the array should have as its elements positive and
negative integer interspersed, e.g. [1, -2, 3, -1, ...].

=head1 AUTHOR

  Steven Haryanto <stevenharyanto@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2009 by Steven Haryanto.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

