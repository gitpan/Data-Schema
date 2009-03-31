package Data::Schema::Type::Hash;

=head1 NAME

Data::Schema::Type::Hash - Type handler for hash ('hash')

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
use Storable qw/freeze/;

sub cmp {
    my ($self, $a, $b) = @_;
    my $res = freeze($a) cmp freeze($b);
    return 0 if $res == 0;
    return undef; # because -1 or 1 doesn't make any sense (yet) for hash
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

Aside from most attributes derived from L<Data::Schema::Type::Base> like
B<is>, B<one_of>, hash also has these type attributes:

=head2 max_len => N

Require that hash does not have more than N keys.

Synonyms: maxlen, max_length, maxlength

=cut

sub handle_attr_max_len {
    my ($self, $data, $arg) = @_;
    if (keys(%$data) > $arg) {
        $self->validator->log_error("number of keys must not exceed $arg");
        return;
    }
    1;
}

# aliases
sub handle_attr_maxlen { handle_attr_max_len(@_) }
sub handle_attr_max_length { handle_attr_max_len(@_) }
sub handle_attr_maxlength { handle_attr_max_len(@_) }

=head2 min_len => N

Require that hash does not have less than N keys.

Synonyms: minlen, min_length, minlength

=cut

sub handle_attr_min_len {
    my ($self, $data, $arg) = @_;
    if (keys(%$data) < $arg) {
        $self->validator->log_error("number of keys must be at least $arg");
        return;
    }
    1;
}

# aliases
sub handle_attr_minlen { handle_attr_min_len(@_) }
sub handle_attr_min_length { handle_attr_min_len(@_) }
sub handle_attr_minlength { handle_attr_min_len(@_) }

=head2 len_between => [MIN, MAX]

A convenience attribute which combines max_len and min_len.

Synonyms: length_between

=cut

sub handle_attr_len_between {
    my ($self, $data, $arg) = @_;
    my $l = keys(%$data);
    if ($l < $arg->[0] || $l > $arg->[1]) {
        $self->validator->log_error("number of keys must be between $arg->[0] and $arg->[1])");
        return;
    }
    1;
}

# aliases
sub handle_attr_length_between { handle_attr_len_between(@_) }

=head2 len => N

Require that hash have exactly N keys.

Synonyms: length

=cut

sub handle_attr_len {
    my ($self, $data, $arg) = @_;
    if (keys(%$data) != $arg) {
        $self->validator->log_error("number of keys must be $arg");
        return;
    }
    1;
}

# aliases
sub handle_attr_length { handle_attr_len(@_) }

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

=head2 keys_regex => REGEX

Require that all hash keys must match a regular expression.

Synonyms: keys_regexp

=cut

sub handle_attr_keys_regex {
    my ($self, $data, $arg) = @_;
    $self->_for_each_key($data, $arg,
                         sub {
                            (!ref($_[0]) && $_[0] =~ qr/$_[2]/) ?
                                '' :
                                "$_[0] must match regex $_[2]"
                         });
}

# aliases
sub handle_attr_keys_regexp { handle_attr_keys_regex(@_) }

=head2 keys_not_regex => REGEX

This is the opposite of B<keys_regex>, forbidding all hash keys from matching a
regular expression.

Synonyms: keys_not_regexp

=cut

sub handle_attr_keys_not_regex {
    my ($self, $data, $arg) = @_;
    $self->_for_each_key($data, $arg,
                         sub {
                            (!ref($_[0]) && $_[0] !~ qr/$_[2]/) ?
                                '' :
                                "$_[0] must not match regex $_[2]"
                         });
}

# aliases
sub handle_attr_keys_not_regexp { handle_attr_keys_not_regex(@_) }

=head2 keys_one_of => [VALUE, ...]

Specify that all hash keys must belong to a list of specified values.

Synonyms: keys, keys_oneof, allowed_keys

For example (in YAML):

 [hash, {allowed_keys: [name age address]}]

This specifies that only keys 'name', 'age', 'address' are allowed (but none are
required).

=cut

sub handle_attr_keys_one_of {
    my ($self, $data, $arg) = @_;
    $self->_for_each_key($data, $arg,
                         sub {
                            (grep {$_[0] eq $_} @$arg) ?
                                '' :
                                (@$arg ==1 ?
                                   "key must be $arg" :
                                 @$arg < 10 ?
                                   "key must be one of @$arg" :
                                   "key does not belong to list of valid keys")
                         });
}

# aliases
sub handle_attr_keys_oneof { handle_attr_keys_one_of(@_) }
sub handle_attr_allowed_keys { handle_attr_keys_one_of(@_) }

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

Synonyms: required_keys_regexp

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

# aliases
sub handle_attr_required_keys_regexp { handle_attr_required_keys_regex(@_) }

=head2 keys_schema => {KEY=>SCHEMA1, KEY2=>SCHEMA2, ...}

Specify schema for hash keys (hash values, actually).

Synonyms: keys

For example (in YAML):

 [hash, {keys: { name: str, age: [int, {min: 0}] } }]

This specifies that the value for key 'name' must be a string, and the value for
key 'age' must be a positive integer.

=cut

sub handle_attr_keys_schema {
    my ($self, $data, $arg) = @_;
    my $has_err = 0;

    if (ref($arg) ne 'HASH') {
        $self->validator->log_error("schema error: keys_schema must be hash");
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

sub handle_attr_keys {
    my ($self, $data, $arg) = @_;
    if (ref($arg) eq 'HASH') {
        return handle_attr_keys_schema(@_);
    } elsif (ref($arg) eq 'ARRAY') {
        return handle_attr_keys_one_of(@_);
    } else {
        $self->validator->log_error("schema error: keys must be hash/array");
        return 0;
    }
}

=head2 all_keys_schema => SCHEMA1

Specify schema for all hash keys (hash values, actually).

Synonyms: of

For example (in YAML):

 [hash, {of: int}]

This specifies that all hash values for must be ints.

=cut

sub handle_attr_all_keys_schema {
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

# aliases
sub handle_attr_of { handle_attr_all_keys_schema(@_) }

=head2 keys_regex_schema => {REGEX1=>SCHEMA1, REGEX2=>SCHEMA2, ...}

Similar to B<keys_schema> but instead of specifying schema for each key, we
specify schema for each set of keys using regular expression.

Synonyms: keys_regexp_schema

For example:

 [hash=>{keys_regex_schema=>{ '\d+'=>"int", '^\D+$'=>"str" }}]

This specifies that for all keys which contain a digit, the values must be int,
while for all non-digit-containing keys, the values must be str. Example: {
a=>"a", a1=>1, a2=>-3, b=>1 }. Note: b=>1 is valid because 1 is a valid str.

=cut

sub handle_attr_keys_regex_schema {
    my ($self, $data, $arg) = @_;
    my $has_err = 0;

    if (ref($arg) ne 'HASH') {
        $self->validator->log_error("schema error: keys_regex_schema must be hash");
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

# aliases
sub handle_attr_keys_regexp_schema { handle_attr_keys_regex_schema(@_) }

=head2 values_regex => REGEX

Specifies that all values must be scalar and match regular expression.

Synonyms: values_regexp

=cut

sub handle_attr_values_regex {
    my ($self, $data, $arg) = @_;
    $self->_for_each_key($data, $arg,
                         sub {
                            (!ref($_[1]) && $_[1] =~ qr/$_[2]/) ?
                                '' :
                                "$_[1] must match regex $_[2]"
                         });
}

# aliases
sub handle_attr_values_regexp { handle_attr_values_regex(@_) }

=head2 values_not_regex => REGEX

The opposite of B<values_regex>, requires that all values not match regular
expression (but must be a scalar).

Synonyms: values_not_regexp

=cut

sub handle_attr_values_not_regex {
    my ($self, $data, $arg) = @_;
    $self->_for_each_key($data, $arg,
                         sub {
                            (!ref($_[1]) && $_[1] !~ qr/$_[2]/) ?
                                '' :
                                "$_[1] must not match regex $_[2]"
                         });
}

# aliases
sub handle_attr_values_not_regexp { handle_attr_values_not_regex(@_) }

=head1 SYNOPSIS

 use Data::Schema;

=head1 AUTHOR

Steven Haryanto, C<< <steven at masterweb.net> >>

=head1 COPYRIGHT & LICENSE

Copyright 2009 Steven Haryanto, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut

__PACKAGE__->meta->make_immutable;
1;
