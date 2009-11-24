package Data::Schema::Type::HasElement;
our $VERSION = '0.12';


# ABSTRACT: Role for types that have the notion of elements


use Moose::Role;
requires map { ("_$_", "_emitpl_$_") } qw/length element indexes/;


sub handle_attr_max_len {
    my ($self, $data, $arg) = @_;
    if ($self->_length($data) > $arg) {
        $self->validator->data_error("length must not exceed $arg");
        return;
    }
    1;
}

sub emitpl_attr_max_len {
    my ($self, $arg) = @_;
    my $perl = '';
    $perl .= $self->validator->emitpl_my('$len');
    $perl .= '$len = '.$self->_emitpl_length('$data').";\n" unless $self->validator->stash->{C_calc_len}++;
    $perl .= "if (\$len > $arg) { ".$self->validator->emitpl_data_error("length must not exceed $arg")." }\n";
    $perl;
}

# aliases
sub handle_attr_maxlen     { handle_attr_max_len(@_) }
sub emitpl_attr_maxlen     { emitpl_attr_max_len(@_) }
sub handle_attr_maxlength  { handle_attr_max_len(@_) }
sub emitpl_attr_maxlength  { emitpl_attr_max_len(@_) }
sub handle_attr_max_length { handle_attr_max_len(@_) }
sub emitpl_attr_max_length { emitpl_attr_max_len(@_) }


sub handle_attr_min_len {
    my ($self, $data, $arg) = @_;
    if ($self->_length($data) < $arg) {
        $self->validator->data_error("length must be at least $arg");
        return;
    }
    1;
}

sub emitpl_attr_min_len {
    my ($self, $arg) = @_;
    my $perl = '';
    $perl .= $self->validator->emitpl_my('$len');
    $perl .= '$len = '.$self->_emitpl_length('$data').";\n" unless $self->validator->stash->{C_calc_len}++;
    $perl .= "if (\$len < $arg) { ".$self->validator->emitpl_data_error("length must be at least $arg")." }\n";
    $perl;
}

# aliases
sub handle_attr_minlen     { handle_attr_min_len(@_) }
sub emitpl_attr_minlen     { emitpl_attr_min_len(@_) }
sub handle_attr_min_length { handle_attr_min_len(@_) }
sub emitpl_attr_min_length { emitpl_attr_min_len(@_) }
sub handle_attr_minlength  { handle_attr_min_len(@_) }
sub emitpl_attr_minlength  { emitpl_attr_min_len(@_) }


sub handle_attr_len_between {
    my ($self, $data, $arg) = @_;
    my $l = $self->_length($data);
    if ($l < $arg->[0] || $l > $arg->[1]) {
        $self->validator->data_error("length must be between $arg->[0] and $arg->[1])");
        return;
    }
    1;
}

sub emitpl_attr_len_between {
    my ($self, $arg) = @_;
    my $perl = '';
    $perl .= $self->validator->emitpl_my('$len');
    $perl .= '$len = '.$self->_emitpl_length('$data').";\n" unless $self->validator->stash->{C_calc_len}++;
    $perl .= "if (\$len < $arg->[0] || \$len > $arg->[1]) { ".$self->validator->emitpl_data_error("length must be between $arg->[0] and $arg->[1]")." }\n";
    $perl;
}

# aliases
sub handle_attr_length_between { handle_attr_len_between(@_) }
sub emitpl_attr_length_between { emitpl_attr_len_between(@_) }


sub handle_attr_len {
    my ($self, $data, $arg) = @_;
    if ($self->_length($data) != $arg) {
        $self->validator->data_error("length must be $arg");
        return;
    }
    1;
}

sub emitpl_attr_len {
    my ($self, $arg) = @_;
    my $perl = '';
    $perl .= $self->validator->emitpl_my('$len');
    $perl .= '$len = '.$self->_emitpl_length('$data').";\n" unless $self->validator->stash->{C_calc_len}++;
    $perl .= "if (\$len != $arg) { ".$self->validator->emitpl_data_error("length must be $arg")." }\n";
    $perl;
}

# aliases
sub handle_attr_length { handle_attr_len(@_) }
sub emitpl_attr_length { emitpl_attr_len(@_) }


sub handle_attr_all_elements {
    my ($self, $data, $arg) = @_;
    my $has_err = 0;

    my @indexes = $self->_indexes($data);
    push @{ $self->validator->data_pos }, $indexes[0];
    for my $i (@indexes) {
        $self->validator->data_pos->[-1] = $i;
        if (!$self->validator->_validate($self->_element($data, $i), $arg)) {
            $has_err++;
        }
        last if $self->validator->too_many_errors;
    }
    pop @{ $self->validator->data_pos };
    !$has_err;
}

sub emitpl_attr_all_elements {
    my ($self, $arg) = @_;
    my $ds = $self->validator;
    my $perl = '';

    my ($code, $csubname) = $ds->emitpls_sub($arg);
    $perl .= $code;
    
    $perl .= $self->validator->emitpl_my('@indexes');
    $perl .= '@indexes = '.$self->_emitpl_indexes('$data').";\n";
    $perl .= 'push @$datapos, $indexes[0];'."\n";
    $perl .= 'for my $i (@indexes) {'."\n";
    $perl .= '    $datapos->[-1] = $i;'."\n";
    $perl .= '    my ($suberrors) = '.$csubname.'('.$self->_emitpl_element('$data', '$i', 1).', $datapos, $schemapos);'."\n";
    $perl .= '    push @errors, @$suberrors;'."\n";
    $perl .= '    if (@errors > '.$ds->config->max_errors.') { last L1 }'."\n";
    $perl .= "}\n";
    $perl .= 'pop @$datapos;'."\n";
    $perl;
}

# aliases
sub handle_attr_all_element { handle_attr_all_elements(@_) }
sub emitpl_attr_all_element { emitpl_attr_all_elements(@_) }
sub handle_attr_all_elems   { handle_attr_all_elements(@_) }
sub emitpl_attr_all_elems   { emitpl_attr_all_elements(@_) }
sub handle_attr_all_elem    { handle_attr_all_elements(@_) }
sub emitpl_attr_all_elem    { emitpl_attr_all_elements(@_) }

sub _for_each_element {
    my ($self, $data, $arg, $checkfail_sub) = @_;
    my $has_err = 0;

    my @indexes = $self->_indexes($data);
    push @{ $self->validator->data_pos }, $indexes[0];
    foreach my $k (@indexes) {
        my $v = $self->_element($data, $k);
        $self->validator->data_pos->[-1] = $k;
        my $errmsg = $checkfail_sub->($k, $v, $arg);
        if ($errmsg) {
            $has_err++;
            $self->validator->data_error($errmsg);
            last if $self->validator->too_many_errors;
        }
    }
    pop @{ $self->validator->data_pos };
    !$has_err;
}

# $code is string of perl code which must act on $arg, $k, $v and set $err
sub _emitpl_for_each_element {
    my ($self, $arg, $code) = @_;
    my $perl = '';

    $perl .= $self->validator->emitpl_my('@indexes', '$arg');
    $perl .= '$arg = '.$self->_perl($arg).";\n";
    $perl .= '@indexes = '.$self->_emitpl_indexes('$data').";\n";
    $perl .= 'push @$datapos, $indexes[0];'."\n";
    $perl .= 'for my $k (@indexes) {'."\n";
    $perl .= '    my $err;'."\n";
    $perl .= '    my $v = '.$self->_emitpl_element('$data', '$k', 1).";\n";
    $perl .= '    $datapos->[-1] = $k;'."\n";
    $perl .= join("", map {"    $_\n"} split /\n/, $code);
    $perl .= '    if ($err) { '.$self->validator->emitpl_data_error('$err', 1)." }\n";
    $perl .= "}\n";
    $perl .= 'pop @$datapos;'."\n";
    $perl;
}


sub handle_attr_deps {
    my ($self, $data, $arg) = @_;
    my $has_err = 0;

    my $ds = $self->validator;

    if (ref($arg) ne 'ARRAY') {
        $ds->schema_error("`deps' attribute must be arrayref");
        return;
    }

    push @{ $ds->schema_pos }, 0;
    for my $i (0..scalar(@$arg)-1) {
        $ds->schema_pos->[-1] = $i;
        if (ref($arg->[$i]) ne 'ARRAY' || scalar(@{ $arg->[$i] }) != 4) {
            $ds->schema_error("deps[$i] must be a 4-element array");
            return;
        }
        my ($idx1, $schema1, $idx2, $schema2) = @{ $arg->[$i] };
        my $elem1 = $self->_element($data, $idx1);
        my $elem2 = $self->_element($data, $idx2);

        $ds->save_validation_state();
        $ds->init_validation_state();
        $ds->_validate($elem1, $schema1);
        my $match1 = !@{ $ds->errors };
	$ds->restore_validation_state();
        if ($match1) {
            push @{ $ds->data_pos }, $idx2;
	    my $pos_before = @{ $ds->errors };
	    $ds->_validate($elem2, $schema2);
	    pop @{ $ds->data_pos };
            my $match2 = $pos_before == @{ $ds->errors };
	    if (!$match2) { $has_err++; last if $ds->too_many_errors }
        }
    }
    pop @{ $ds->schema_pos };
    !$has_err;
}

sub emitpl_attr_deps {
    my ($self, $arg) = @_;
    my $perl = '';
    my $ds = $self->validator;

    if (ref($arg) ne 'ARRAY') { $ds->schema_error("`deps' attribute must be arrayref"); return }
    my $i=0; for (@$arg) { unless (ref($_) eq 'ARRAY' && @$_ == 4) { $ds->schema_error("`deps'[$i] attribute must be 4-element array"); return } $i++ }

    my @arg;
    for my $i (0..scalar(@$arg)-1) {
	my ($code1, $csubname1) = $ds->emitpls_sub($arg->[$i][1]);
	my ($code2, $csubname2) = $ds->emitpls_sub($arg->[$i][3]);
	$perl .= $code1 . $code2;
	push @arg, [$arg->[$i][0], $csubname1, $arg->[$i][2], $csubname2];
    }

    $perl .= $self->validator->emitpl_my('@arg');
    $perl .= '@arg = ('.join(", ", map {"[".$self->_perl($_->[0]).", \\&$_->[1], ".$self->_perl($_->[2]).", \\&$_->[3]]"} @arg).");\n";
    $perl .= 'push @$datapos, -1;'."\n";
    $perl .= 'push @$schemapos, -1;'."\n";
    $perl .= 'for my $i (0..scalar(@arg)-1) {'."\n";
    $perl .= '    my ($idx1, $schema1, $idx2, $schema2) = @{ $arg[$i] };'."\n";
    $perl .= '    $datapos->[-1] = $idx2;'."\n";
    $perl .= '    $schemapos->[-1] = $i;'."\n";
    $perl .= '    my $elem1 = '.$self->_emitpl_element('$data', '$idx1', 1).";\n";
    $perl .= '    my $elem2 = '.$self->_emitpl_element('$data', '$idx2', 1).";\n";
    $perl .= '    my ($suberrors1) = $schema1->($elem1);'."\n";
    $perl .= '    next if @$suberrors1;'."\n";
    $perl .= '    my ($suberrors2) = $schema2->($elem2, $datapos, $schemapos);'."\n";
    $perl .= '    push @errors, @$suberrors2; last L1 if @errors >= '.$ds->config->max_errors."\n";
    $perl .= "}\n";
    $perl .= 'pop @$datapos;'."\n";
    $perl .= 'pop @$schemapos;'."\n";
    $perl;
}

no Moose::Role;
1;

__END__
=pod

=head1 NAME

Data::Schema::Type::HasElement - Role for types that have the notion of elements

=head1 VERSION

version 0.12

=head1 SYNOPSIS

    use Data::Schema;

=head1 DESCRIPTION

This is the role for types that have the notion of length. It provides
attributes like maxlen, length, length_between, all_elements, etc. It is used by
'str', 'array', and also 'hash'.

Role consumer must provide methods:

* '_length()' which returns the length;

* '_element(idx)' which returns the element at idx;

* '_indexes()' which returns all element indexes.

=head1 TYPE ATTRIBUTES

=head2 max_len => LEN

Requires that the data have at most LEN elements.

Synonyms: maxlen, max_length, maxlength

=head2 min_len => LEN

Requires that the data have at least LEN elements.

Synonyms: minlen, min_length, minlength

=head2 len_between => [MIN, MAX]

A convenience attribute that combines B<minlen> and B<maxlen>.

Synonyms: length_between

=head2 len => LEN

Requires that the data have exactly LEN elements.

Synonyms: length

=head2 all_elements => SCHEMA

Requires that every element of the data validate to the specified schema.

Synonyms: all_element, all_elems, all_elem

Examples (in YAML):

 [array, {all_elements: int}]

The above specifies an array of ints.

 [hash, {all_elements: [str: {match: '^[A-Za-z0-9]+$'}]}]

The above specifies hash with alphanumeric-only values.

=head2 deps => [[ELEMIDX1 => SCHEMA1, ELEMIDX2 => SCHEMA2], ...]

Specify inter-element dependencies. If element at ELEMIDX1 matches SCHEMA1,
then element at ELEMIDX2 must match SCHEMA2.

Examples (in YAML):

 - hash
 - deps: [[ password, [str, {set: 1}], password_confirmation, [str, {set: 1}] ]]

The above says: key 'password_confirmation' is required if 'password' is set.

 - hash
 - deps: [[ province, [str, {set: 1, is: 'Outside US'}],
            zipcode,  [str, {set: 0}] ],
          [ province, [str, {set: 1, not: 'Outside US'}],
            zipcode,  [str, {set: 1}] ]
         ]

The above says: if province is set to 'Outside US', then zipcode must not be
specified. Otherwise if province is set to US states, zipcode is required.

TODO: a simpler syntax for common cases like: A is required if B if specified,
e.g. instead of:

 deps: [[ B, [int, {set: 1}], A, [int, {set: 1}] ]]

we can perhaps say:

 required_deps: [B => A]

TODO: dependencies between elements of different array/hash.

=head1 AUTHOR

  Steven Haryanto <stevenharyanto@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2009 by Steven Haryanto.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

