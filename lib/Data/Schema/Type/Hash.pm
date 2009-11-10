package Data::Schema::Type::Hash;

=head1 NAME

Data::Schema::Type::Hash - Type handler for hash ('hash')

=head1 SYNOPSIS

 use Data::Schema;

=head1 DESCRIPTION

This is the type handler for type 'hash'.

Example schema (in YAML syntax):

 - hash
 - required_keys: [name, age]
   allowed_keys: [name, age, note]
   keys:
     name: str
     age: [int, {min: 0}]

Example valid data:

 {name: Lisa, age: 14, note: "Bart's sister"}

Example invalid data:

 []                             # not a hash
 {name: Lisa}                   # doesn't have the required key: age
 {name: Lisa, age: -1}          # age must be positive integer
 {name: Lisa, age: 14, sex: F}  # sex is not in list of allowed keys

=cut

use Moose;
extends 'Data::Schema::Type::Base';
with 'Data::Schema::Type::Comparable', 'Data::Schema::Type::HasLength';
use Storable qw/freeze/;

sub _equal {
    my ($self, $a, $b) = @_;
    (freeze($a) cmp freeze($b)) == 0;
}

sub _length {
    my ($self, $data) = @_;
    scalar keys %$data;
}

sub handle_pre_check_attrs {
    my ($self, $data) = @_;
    if (ref($data) ne 'HASH') {
        $self->validator->log_error("must be a hash");
        return;
    }
    1;
}

=head1 TYPE ATTRIBUTES

Hashes are Comparable and HasLength, so you might want to consult the docs of
those roles to see what type attributes are available.

Aside from those, hash also has these type attributes:

=cut

sub _for_each_key {
    my ($self, $data, $arg, $checkfail_sub) = @_;
    my $has_err = 0;

    push @{ $self->validator->data_pos }, [''];
    foreach my $k (keys %$data) {
        my $v = $data->{$k};
        $self->validator->data_pos->[-1] = $k;
        my $errmsg = $checkfail_sub->($k, $v, $arg);
        if ($errmsg) {
            $has_err++;
            $self->validator->log_error($errmsg);
            last if $self->validator->too_many_errors;
        }
    }
    pop @{ $self->validator->data_pos };
    !$has_err;
}

=head2 keys_match => REGEX

Require that all hash keys must match a regular expression.

=cut

sub handle_attr_keys_match {
    my ($self, $data, $arg) = @_;
    $self->_for_each_key($data, $arg,
                         sub {
                            (!ref($_[0]) && $_[0] =~ qr/$_[2]/) ?
                                '' :
                                "$_[0] must match regex $_[2]"
                         });
}

=head2 keys_not_match => REGEX

This is the opposite of B<keys_match>, forbidding all hash keys from matching a
regular expression.

=cut

sub handle_attr_keys_not_match {
    my ($self, $data, $arg) = @_;
    $self->_for_each_key($data, $arg,
                         sub {
                            (!ref($_[0]) && $_[0] !~ qr/$_[2]/) ?
                                '' :
                                "$_[0] must not match regex $_[2]"
                         });
}

=head2 keys_one_of => [VALUE, ...]

Specify that all hash keys must belong to a list of specified values.

Synonyms: allowed_keys

For example (in YAML):

 [hash, {allowed_keys: [name, age, address]}]

This specifies that only keys 'name', 'age', 'address' are allowed (but none are
required).

=cut

sub handle_attr_keys_one_of {
    my ($self, $data, $arg) = @_;
    $self->_for_each_key($data, $arg,
                         sub {
                            # XXX early exit
                            (grep {$_[0] eq $_} @$arg) ?
                                '' :
                                (@$arg ==1 ?
                                   "key must be $arg->[0]" :
                                 @$arg < 10 ?
                                   "key must be one of @$arg" :
                                   "key does not belong to list of valid keys")
                         });
}

# aliases
sub handle_attr_allowed_keys { handle_attr_keys_one_of(@_) }

=head2 values_one_of => [VALUE, ...]

Specify that all hash values must belong to a list of specified values.

Synonyms: allowed_values

For example (in YAML):

 [hash, {allowed_values: [1, 2, 3, 4, 5]}]

=cut

sub handle_attr_values_one_of {
    my ($self, $data, $arg) = @_;
    $self->_for_each_key($data, $arg,
                         sub {
                            # XXX early exit
                            (grep {ref($_[1]) ? ($self->cmp($_[1], $_) == 0) : ($_[1] eq $_)} @$arg) ?
                                '' :
                                # XXX complex value must be dumped
                                (@$arg ==1 ?
                                   "value must be $arg->[0]" :
                                 @$arg < 10 ?
                                   "value must be one of @$arg" :
                                   "values does not belong to list of valid values")
                         });
}

# aliases
sub handle_attr_allowed_values { handle_attr_values_one_of(@_) }

=head2 required_keys => [KEY1, KEY2. ...]

Require that certain keys exist in the hash.

=cut

sub handle_attr_required_keys {
    my ($self, $data, $arg) = @_;
    my %checked_keys = map {$_=>0} @$arg;

    foreach my $k (keys %$data) {
        if (grep { $k eq $_ } @$arg) {
            $checked_keys{$k}++ if defined($data->{$k});
        }
    }
    my @missing_keys = grep {!$checked_keys{$_}} keys %checked_keys;
    if (@missing_keys) {
        $self->validator->log_error("missing keys: ".join(", ", @missing_keys));
        return 0;
    }
    1;
}

=head2 required_keys_regex => REGEX

Require that keys matching a regular expression exist in the hash

=cut

sub handle_attr_required_keys_regex {
    my ($self, $data, $arg) = @_;
    my @missing_keys;

    foreach my $k (keys %$data) {
        if ($k =~ qr/$arg/) {
            push @missing_keys, $k unless defined($data->{$k});
        }
    }
    if (@missing_keys) {
        $self->validator->log_error("missing keys: ".join(", ", @missing_keys));
    }
    1;
}

=head2 keys => {KEY=>SCHEMA1, KEY2=>SCHEMA2, ...}

Specify schema for hash keys (hash values, actually).

For example (in YAML):

 [hash, {keys: { name: str, age: [int, {min: 0}] } }]

This specifies that the value for key 'name' must be a string, and the value for
key 'age' must be a positive integer.

=cut

sub handle_attr_keys {
    my ($self, $data, $arg) = @_;
    my $has_err = 0;

    if (ref($arg) ne 'HASH') {
        $self->validator->log_error("schema error: `keys' attribute must be hash");
        return;
    }

    push @{ $self->validator->data_pos }, '';
    foreach my $k (keys %$data) {
        next unless exists $arg->{$k};
        $self->validator->data_pos->[-1] = $k;
        push @{ $self->validator->schema_pos }, $k;
        if (!$self->validator->_validate($data->{$k}, $arg->{$k})) {
            $has_err++;
        }
        pop @{ $self->validator->schema_pos };
        last if $self->validator->too_many_errors;
    }
    pop @{ $self->validator->data_pos };
    !$has_err;
}

=head2 keys_of => SCHEMA

Specify a schema for all hash keys.

For example (in YAML):

 [hash, {keys_of: int}]

This specifies that all hash keys must be ints.

=cut

sub handle_attr_keys_of {
    my ($self, $data, $arg) = @_;
    my $has_err = 0;

    push @{ $self->validator->data_pos }, '';
    foreach my $k (keys %$data) {
        $self->validator->data_pos->[-1] = $k;
        if (!$self->validator->_validate($k, $arg)) {
            $has_err++;
        }
        last if $self->validator->too_many_errors;
    }
    pop @{ $self->validator->data_pos };
    !$has_err;
}

=head2 values_of => SCHEMA

Specify a schema for all hash values.

For example (in YAML):

 [hash, {values_of: int}]

This specifies that all hash values must be ints.

=cut

sub handle_attr_values_of {
    my ($self, $data, $arg) = @_;
    my $has_err = 0;

    push @{ $self->validator->data_pos }, '';
    foreach my $k (keys %$data) {
        $self->validator->data_pos->[-1] = $k;
        if (!$self->validator->_validate($data->{$k}, $arg)) {
            $has_err++;
        }
        last if $self->validator->too_many_errors;
    }
    pop @{ $self->validator->data_pos };
    !$has_err;
}

=head2 of => [SCHEMA_FOR_KEYS, SCHEMA_FOR_VALUES]

Specify a pair of schemas for all keys and values.

For example (in YAML):

 [hash, {of: [int, int]}]

This specifies that all hash keys as well as values must be ints.

=cut

sub handle_attr_of {
    my ($self, $data, $arg) = @_;
    my $has_err = 0;

    push @{ $self->validator->data_pos }, '';
    foreach my $k (keys %$data) {
        $self->validator->data_pos->[-1] = $k;
        if (!$self->validator->_validate($k, $arg->[0])) {
            $has_err++;
        }
        last if $self->validator->too_many_errors;
        if (!$self->validator->_validate($data->{$k}, $arg->[1])) {
            $has_err++;
        }
        last if $self->validator->too_many_errors;
    }
    pop @{ $self->validator->data_pos };
    !$has_err;
}

=head2 some_of => [[KEY_SCHEMA, VALUE_SCHEMA, MIN, MAX], [KEY_SCHEMA2, VALUE_SCHEMA2, MIN2, MAX2], ...]

Requires that some elements be of certain type. TYPE is the name of the type,
MIN and MAX are numbers, -1 means unlimited.

Example (in YAML):

 [hash, {some_of: [[
   [str, {one_of: [userid, username, email]}],
   [str, {required: Yes}],
   1, 1
 ]]}]

The above requires that the hash has *either* userid, username, or
email key specified but not both or three of them. In other words, the
hash has to choose to specify only one of the three.

=cut

sub handle_attr_some_of {
    my ($self, $data, $arg) = @_;
    my @num_valid = map {0} 1..@$arg;
    my $ds = $self->validator;

    $ds->save_validation_state();
    my $j = 0;
    for my $r (@$arg) {
        for my $k (keys %$data) {
            my $v = $data->{$k};
            $ds->init_validation_state();
            $ds->_validate($k, $r->[0]);
            my $k_ok = !@{ $ds->errors };
            $ds->init_validation_state();
            $ds->_validate($v, $r->[1]);
            my $v_ok = !@{ $ds->errors };
            $num_valid[$j]++ if $k_ok && $v_ok;
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
        my $a = $r->[2];
        my $b = $r->[3];
        if ($a != -1 && $m < $a) {
            my $x = !ref($r->[0]) ? $r->[0] : ref($r->[0]) eq 'ARRAY' ? "[$r->[0][0] => ...]" : "{type=>$r->[0]{type}, ...}";
            my $y = !ref($r->[1]) ? $r->[1] : ref($r->[1]) eq 'ARRAY' ? "[$r->[1][0] => ...]" : "{type=>$r->[1]{type}, ...}";
            $ds->log_error("hash must contain at least $a pairs of types $x => $y");
            $has_err++;
            last if $ds->too_many_errors;
        }
        if ($b != -1 && $m > $b) {
            my $x = !ref($r->[0]) ? $r->[0] : ref($r->[0]) eq 'ARRAY' ? "[$r->[0][0] => ...]" : "{type=>$r->[0]{type}, ...}";
            my $y = !ref($r->[1]) ? $r->[1] : ref($r->[1]) eq 'ARRAY' ? "[$r->[1][0] => ...]" : "{type=>$r->[1]{type}, ...}";
            $ds->log_error("hash must contain at most $b pairs of types $x => $y");
            $has_err++;
            last if $ds->too_many_errors;
        }
        $j++;
    }
    pop @{ $ds->schema_pos };

    !$has_err;
}

=head2 keys_regex => {REGEX1=>SCHEMA1, REGEX2=>SCHEMA2, ...}

Similar to B<keys> but instead of specifying schema for each key, we specify
schema for each set of keys using regular expression.

For example:

 [hash=>{keys_regex=>{ '\d'=>"int", '^\D+$'=>"str" }}]

This specifies that for all keys which contain a digit, the values must be int,
while for all non-digit-containing keys, the values must be str. Example: {
a=>"a", a1=>1, a2=>-3, b=>1 }. Note: b=>1 is valid because 1 is a valid str.

=cut

sub handle_attr_keys_regex {
    my ($self, $data, $arg) = @_;
    my $has_err = 0;

    if (ref($arg) ne 'HASH') {
        $self->validator->log_error("schema error: `keys_regex' attribute must be hash");
        return;
    }

    push @{ $self->validator->data_pos }, '';
    for my $k (keys %$data) {
        $self->validator->data_pos->[-1] = $k;
        for my $ks (keys %$arg) {
            next unless $k =~ qr/$ks/;
            push @{ $self->validator->schema_pos }, $ks;
            if (!$self->validator->_validate($data->{$k}, $arg->{$ks})) {
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

=head2 values_match => REGEX

Specifies that all values must be scalar and match regular expression.

=cut

sub handle_attr_values_match {
    my ($self, $data, $arg) = @_;
    $self->_for_each_key($data, $arg,
                         sub {
                            (!ref($_[1]) && $_[1] =~ qr/$_[2]/) ?
                                '' :
                                "$_[1] must match regex $_[2]"
                         });
}

=head2 values_not_match => REGEX

The opposite of B<values_match>, requires that all values not match regular
expression (but must be a scalar).

=cut

sub handle_attr_values_not_match {
    my ($self, $data, $arg) = @_;
    $self->_for_each_key($data, $arg,
                         sub {
                            (!ref($_[1]) && $_[1] !~ qr/$_[2]/) ?
                                '' :
                                "$_[1] must not match regex $_[2]"
                         });
}

sub english {
    my ($self, $schema, $opt) = @_;
    $schema = $self->validator->normalize_schema($schema)
        unless ref($schema) eq 'HASH';

    if (@{ $schema->{attr_hashes} }) {
        for my $alias (qw/of/) {
            my $of = $schema->{attr_hashes}[0]{$alias};
            next unless $of;
            my $sk = $of->[0];
            my $sv = $of->[1];
            $sk = $self->validator->normalize_schema($sk) unless ref($sk) eq 'HASH';
            $sv = $self->validator->normalize_schema($sv) unless ref($sv) eq 'HASH';
            my $th;
            $th = $self->validator->get_type_handler($sk->{type});
            my $ek = $th->english($sk, $opt);
            $th = $self->validator->get_type_handler($sv->{type});
            my $ev = $th->english($sk, $opt);
            return "hash of ($ek => $ev)";
        }
        for my $alias (qw/keys_of/) {
            my $sk = $schema->{attr_hashes}[0]{$alias};
            next unless $sk;
            $sk = $self->validator->normalize_schema($sk) unless ref($sk) eq 'HASH';
            my $th;
            $th = $self->validator->get_type_handler($sk->{type});
            my $ek = $th->english($sk, $opt);
            return "hash of ($ek => ...)";
        }
        for my $alias (qw/values_of/) {
            my $sv = $schema->{attr_hashes}[0]{$alias};
            next unless $sv;
            $sv = $self->validator->normalize_schema($sv) unless ref($sv) eq 'HASH';
            my $th;
            $th = $self->validator->get_type_handler($sv->{type});
            my $ev = $th->english($sv, $opt);
            return "hash of (... => $ev)";
        }
    }
    return "all";
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
