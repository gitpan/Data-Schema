package Data::Schema::Type::Array;

=head1 NAME

Data::Schema::Type::Array - Type handler for arrays ('array')

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

=cut

use Moose;
extends 'Data::Schema::Type::Base';
use Storable qw/freeze/;
use List::MoreUtils qw/uniq/;

sub cmp {
    my ($self, $a, $b) = @_;
    my $res = freeze($a) cmp freeze($b);
    return 0 if $res == 0;
    return undef; # because -1 or 1 doesn't make any sense (yet) for array
}

sub handle_pre_check_attrs {
    my ($self, $data) = @_;
    if (ref($data) ne 'ARRAY') {
        $self->validator->log_error("must be an array");
        return;
    }
    1;
}

=head1 TYPE ATTRIBUTES

In addition to attributes provided from DST::Base, like B<one_of>, B<is>, etc,
array has some additional attributes:

=head2 max_len => LEN

Requires that the array have at most LEN elements.

Synonyms: maxlen, max_length, maxlength

=cut

sub handle_attr_max_len {
    my ($self, $data, $arg) = @_;
    if (@$data > $arg) {
        $self->validator->log_error("length must not exceed $arg");
        return;
    }
    1;
}

# aliases
sub handle_attr_maxlen { handle_attr_max_len(@_) }
sub handle_attr_max_length { handle_attr_max_len(@_) }
sub handle_attr_maxlength { handle_attr_max_len(@_) }

=head2 min_len => LEN

Requires that the array have at least LEN elements.

Synonyms: minlen, min_length, minlength

=cut

sub handle_attr_min_len {
    my ($self, $data, $arg) = @_;
    if (@$data < $arg) {
        $self->validator->log_error("length must be at least $arg");
        return;
    }
    1;
}

# aliases
sub handle_attr_minlen { handle_attr_min_len(@_) }
sub handle_attr_min_length { handle_attr_min_len(@_) }
sub handle_attr_minlength { handle_attr_min_len(@_) }

=head2 len_between => [MIN, MAX]

A convenience attribute that combines B<minlen> and B<maxlen>.

Synonyms: length_between

=cut

sub handle_attr_len_between {
    my ($self, $data, $arg) = @_;
    my $l = @$data;
    if ($l < $arg->[0] || $l > $arg->[1]) {
        $self->validator->log_error("length must be between $arg->[0] and $arg->[1])");
        return;
    }
    1;
}

# aliases
sub handle_attr_length_between { handle_attr_len_between(@_) }

=head2 len => LEN

Requires that the array have exactly LEN elements.

Synonyms: length

=cut

sub handle_attr_len {
    my ($self, $data, $arg) = @_;
    if (@$data != $arg) {
        $self->validator->log_error("length must be $arg");
        return;
    }
    1;
}

# aliases
sub handle_attr_length { handle_attr_len(@_) }

=head2 unique => 0 or 1

If unique is 1, require that the array values be unique (like in a set). If
unique is 0, require that there are duplicates in the array.

Note: currently the implementation uses List::MoreUtils' uniq().

=cut

sub handle_attr_unique {
    my ($self, $data, $arg) = @_;
    my $unique = !(@$data > uniq(@$data));
    if (($arg ? 1:0) xor ($unique ? 1:0)) {
        $self->validator->log_error("array must ".($arg ? "":"not ")."be unique");
        return;
    }
    1;
}

=head2 elements => [SCHEMA_FOR_FIRST_ELEMENT, SCHEMA_FOR_SECOND_ELEM, ...]

Requires that each element of the array validates to the specified schemas.

Synonyms: element, elems, elem

Example (in YAML):

 [array, {elements: [ int, str, [int, {min: 0}] ]}]

The above example states that the array must have an int as the first element,
string as the second, and positive integer as the third.

=cut

sub handle_attr_elements {
    my ($self, $data, $arg) = @_;
    my $has_err = 0;

    if (ref($arg) ne 'ARRAY') {
        $self->validator->log_error("schema error: `elements' attribute must be array");
        return;
    }

    push @{ $self->validator->data_pos }, 0;
    for my $i (0..@$arg-1) {
        $self->validator->data_pos->[-1] = $i;
        push @{ $self->validator->schema_pos }, $i;
        if (!$self->validator->_validate($data->[$i], $arg->[$i])) {
            $has_err++;
        }
        pop @{ $self->validator->schema_pos };
        last if $self->validator->too_many_errors;
    }
    pop @{ $self->validator->data_pos };
    !$has_err;
}

# aliases
sub handle_attr_element { handle_attr_elements(@_) }
sub handle_attr_elems { handle_attr_elements(@_) }
sub handle_attr_elem { handle_attr_elements(@_) }

=head2 all_elements => SCHEMA

Requires that every element of the array validates to the specified schema.

Synonyms: of, all_element, all_elems, all_elem

Example (in YAML):

 [array, {of: int}]

The above specifies an array of ints.

=cut

sub handle_attr_all_elements {
    my ($self, $data, $arg) = @_;
    my $has_err = 0;

    push @{ $self->validator->data_pos }, 0;
    for my $i (0..@$data-1) {
        $self->validator->data_pos->[-1] = $i;
        if (!$self->validator->_validate($data->[$i], $arg)) {
            $has_err++;
        }
        last if $self->validator->too_many_errors;
    }
    pop @{ $self->validator->data_pos };
    !$has_err;
}

# aliases
sub handle_attr_all_element { handle_attr_all_elements(@_) }
sub handle_attr_all_elems { handle_attr_all_elements(@_) }
sub handle_attr_all_elem { handle_attr_all_elements(@_) }
sub handle_attr_of { handle_attr_all_elements(@_) }

=head2 some_of => [[TYPE, MIN, MAX], [TYPE, MIN, MAX], ...]

Requires that some elements be of certain type. TYPE is the name of the type,
MIN and MAX are numbers, -1 means unlimited.

Example (in YAML):

 [array, {some_of: [ [int, 1, -1], [str, 3, 3], [float, 0, 1] ]}]

The above requires that the array contains at least one integer, exactly three
strings, and at most one floating number.

=cut

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
            $ds->log_error("array must contain at least $a elements of type $x");
            $has_err++;
            last if $ds->too_many_errors;
        }
        if ($b != -1 && $m > $b) {
            my $x = !ref($r->[0]) ? $r->[0] : ref($r->[0]) eq 'ARRAY' ? "[$r->[0][0] => ...]" : "{type=>$r->[0]{type}, ...}";
            $ds->log_error("array must contain at most $b elements of type $x");
            $has_err++;
            last if $ds->too_many_errors;
        }
        $j++;
    }
    pop @{ $ds->schema_pos };

    !$has_err;
}

=head2 elements_regex => {REGEX=>SCHEMA, REGEX2=>SCHEMA2, ...]

Similar to B<elements>, but instead of specifying schema for each
element, this attribute allows us to specify using regexes which elements we
want to specify schema for.

Synonyms: element_regex, elems_regex, elem_regex

Example (in YAML):

 - array
 - elements_regex:
     '[02468]$': [int, {minex: 0}]
     '[13579]$': [int, {maxex: 0}]

The above example states that the array should have as its elements positive and
negative integer interspersed, e.g. [1, -2, 3, -1, ...].

=cut

sub handle_attr_elements_regex {
    my ($self, $data, $arg) = @_;
    my $has_err = 0;

    if (ref($arg) ne 'HASH') {
        $self->validator->log_error("schema error: `elements_regex' attribute must be hash");
        return;
    }

    push @{ $self->validator->data_pos }, 0;
    for my $i (0..@$data-1) {
        $self->validator->data_pos->[-1] = $i;
        my $found = 0;
        for my $ks (keys %$arg) {
            next unless $i =~ qr/$ks/;
            $found++;
            push @{ $self->validator->schema_pos }, $ks;
            if (!$self->validator->_validate($data->[$i], $arg->{$ks})) {
                $has_err++;
            }
            pop @{ $self->validator->schema_pos };
            last if $self->validator->too_many_errors;
        }
        if (!$found) {
            $self->validator->log_error("invalid element");
            $has_err++;
        }
        last if $self->validator->too_many_errors;
    }
    pop @{ $self->validator->data_pos };
    !$has_err;
}

# aliases
sub handle_attr_element_regex { handle_attr_elements_regex(@_) }
sub handle_attr_elems_regex { handle_attr_elements_regex(@_) }
sub handle_attr_elem_regex { handle_attr_elements_regex(@_) }

sub _for_each_elem {
    my ($self, $data, $arg, $checkfail_sub) = @_;
    my $has_err = 0;

    push @{ $self->validator->data_pos }, 0;
    for my $i (0..@$data-1) {
        my $elem = $data->[$i];
        $self->validator->data_pos->[-1] = $i;
        my $errmsg = $checkfail_sub->($i, $elem, $arg);
        if ($errmsg) {
            $has_err++;
            $self->validator->log_error($errmsg);
            last if $self->validator->too_many_errors;
        }
    }
    pop @{ $self->validator->data_pos };
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
1;
