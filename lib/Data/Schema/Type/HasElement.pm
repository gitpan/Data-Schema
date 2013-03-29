package Data::Schema::Type::HasElement;
our $VERSION = '0.136';


# ABSTRACT: Role for types that have the notion of elements


use Moose::Role;
requires map { ("_$_", "_emitpl_$_") } qw/length element indexes/;


sub chkarg_attr_max_len {
    my ($self, $arg, $name) = @_;
    $self->chkarg_r_int($arg, $name);
}

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

Data::Schema::Type::Base::__make_attr_alias(max_len => qw/maxlen maxlength max_length/);


sub chkarg_attr_min_len { chkarg_attr_max_len(@_) }

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

Data::Schema::Type::Base::__make_attr_alias(min_len => qw/minlen min_length minlength/);


sub chkarg_attr_len_between {
    my ($self, $arg, $name) = @_;
    $self->chkarg_r_array_of_int($arg, $name, 2, 2);
}

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

Data::Schema::Type::Base::__make_attr_alias(len_between => qw/length_between/);


sub chkarg_attr_len { chkarg_attr_max_len(@_) }

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

Data::Schema::Type::Base::__make_attr_alias(len => qw/length/);


sub chkarg_attr_all_elements {
    my ($self, $arg, $name) = @_;
    $self->chkarg_r_schema($arg, $name);
}

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

    $perl .= $ds->emitpl_my('@indexes');
    $perl .= '@indexes = '.$self->_emitpl_indexes('$data').";\n";
    $perl .= 'push @$datapos, $indexes[0];'."\n";
    $perl .= 'for my $i (@indexes) {'."\n";
    $perl .= '    $datapos->[-1] = $i;'."\n";
    $perl .= '    my ($suberrors, $subwarnings) = '.$csubname.'('.$self->_emitpl_element('$data', '$i', 1).', $datapos, $schemapos);'."\n";
    $perl .= '    '.$ds->emitpl_push_errwarn();
    $perl .= "}\n";
    $perl .= 'pop @$datapos;'."\n";
    $perl;
}

Data::Schema::Type::Base::__make_attr_alias(all_elements => qw/all_element all_elems all_elem/);

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


sub chkarg_attr_element_deps {
    my ($self, $arg, $name) = @_;
    $self->chkarg_r_array($arg, $name, 0, 0,
                          sub {
                              my ($arg, $name) = @_;
                              return unless $self->chkarg_r_array($arg, $name, 4, 4);
                              return unless $self->chkarg_r_regex($arg->[0], "$name/0");
                              return unless $self->chkarg_r_schema($arg->[1], "$name/1");
                              return unless $self->chkarg_r_regex($arg->[2], "$name/2");
                              return unless $self->chkarg_r_schema($arg->[3], "$name/3");
                              1;
                          }
                      );
}

sub handle_attr_element_deps {
    my ($self, $data, $arg) = @_;
    my $has_err = 0;

    my $ds = $self->validator;

    push @{ $ds->schema_pos }, 0;
    for my $i (0..scalar(@$arg)-1) {
        $ds->schema_pos->[-1] = $i;
        my ($re1, $schema1, $re2, $schema2) = @{ $arg->[$i] };

        $ds->save_validation_state();
	$ds->init_validation_state();
	my $match1 = 1;
        for my $k ($self->_indexes($data)) {
	    next unless $k =~ qr/$re1/;
	    my $elem = $self->_element($data, $k);
	    $ds->_validate($elem, $schema1);
	    if (@{ $ds->errors }) { $match1 = 0; last }
	}
	$ds->restore_validation_state();
        if ($match1) {
	    $ds->debug("left-side regex matches", 4) if $match1;
	    my $match2 = 1;
	    my $pos_before = @{ $ds->errors };
            push @{ $ds->data_pos }, '';
	    for my $k ($self->_indexes($data)) {
		next unless $k =~ qr/$re2/;
		$ds->data_pos->[-1] = $k;
		my $elem = $self->_element($data, $k);
		$ds->_validate($elem, $schema2);
		do { $has_err++; $match2 = 0 } if @{ $ds->errors } != $pos_before;
		$ds->debug("right-side doesn't match (idx=$k)!", 4) unless $match2;
		last if $ds->too_many_errors;
	    }
	    pop @{ $ds->data_pos };
        }
    }
    pop @{ $ds->schema_pos };
    !$has_err;
}

sub emitpl_attr_element_deps {
    my ($self, $arg) = @_;
    my $perl = '';
    my $ds = $self->validator;

    my @arg;
    for my $i (0..scalar(@$arg)-1) {
	my ($code1, $csubname1) = $ds->emitpls_sub($arg->[$i][1]);
	my ($code2, $csubname2) = $ds->emitpls_sub($arg->[$i][3]);
	$perl .= $code1 . $code2;
	push @arg, [$arg->[$i][0], $csubname1, $arg->[$i][2], $csubname2];
    }

    $perl .= $ds->emitpl_my('@arg');
    $perl .= '@arg = ('.join(", ", map {"[".$self->_perl($_->[0]).", \\&$_->[1], ".$self->_perl($_->[2]).", \\&$_->[3]]"} @arg).");\n";
    $perl .= 'push @$schemapos, -1;'."\n";
    $perl .= 'for my $i (0..scalar(@arg)-1) {'."\n";
    $perl .= '    $schemapos->[-1] = $i;'."\n";
    $perl .= '    my ($re1, $schema1, $re2, $schema2) = @{ $arg[$i] };'."\n";
    $perl .= '    my $match1 = 1;'."\n";
    $perl .= '    for my $k ('.$self->_emitpl_indexes('$data', 1).") {\n";
    $perl .= '        next unless $k =~ qr/$re1/;'."\n";
    $perl .= '        my $elem = '.$self->_emitpl_element('$data', '$k', 1).";\n";
    $perl .= '        my ($suberrors1, $subwarnings1) = $schema1->($elem);'."\n";
    $perl .= '        if (@$suberrors1) { $match1 = 0; last }'."\n";
    $perl .= '    }'."\n";
    $perl .= '    next unless $match1;'."\n";
    $perl .= '    my $match2 = 1;'."\n";
    $perl .= '    push @$datapos, "";'."\n";
    $perl .= '    for my $k ('.$self->_emitpl_indexes('$data', 1).") {\n";
    $perl .= '        next unless $k =~ qr/$re2/;'."\n";
    $perl .= '        $datapos->[-1] = $k;'."\n";
    $perl .= '        my $elem = '.$self->_emitpl_element('$data', '$k', 1).";\n";
    $perl .= '        my ($suberrors2, $subwarnings2) = $schema2->($elem, $datapos, $schemapos);'."\n";
    $perl .= '        '.$ds->emitpl_push_errwarn('suberrors2', 'subwarnings2');
    $perl .= "    }\n";
    $perl .= '    pop @$datapos;'."\n";
    $perl .= "}\n";
    $perl .= 'pop @$schemapos;'."\n";
    $perl;
}

Data::Schema::Type::Base::__make_attr_alias(element_deps => qw/element_dep elem_deps elem_dep/);

no Moose::Role;
1;

__END__
=pod

=head1 NAME

Data::Schema::Type::HasElement - Role for types that have the notion of elements

=head1 VERSION

version 0.136

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

Aliases: maxlen, max_length, maxlength

Requires that the data have at most LEN elements.

=head2 min_len => LEN

Aliases: minlen, min_length, minlength

Requires that the data have at least LEN elements.

=head2 len_between => [MIN, MAX]

Aliases: length_between

A convenience attribute that combines B<minlen> and B<maxlen>.

=head2 len => LEN

Aliases: length

Requires that the data have exactly LEN elements.

=head2 all_elements => SCHEMA

Aliases: all_element, all_elems, all_elem

Requires that every element of the data validate to the specified schema.

Examples (in YAML):

 [array, {all_elements: int}]

The above specifies an array of ints.

 [hash, {all_elements: [str: {match: '^[A-Za-z0-9]+$'}]}]

The above specifies hash with alphanumeric-only values.

=head2 element_deps => [[REGEX1 => SCHEMA1, REGEX1 => SCHEMA2], ...]

Aliases: element_dep, elem_deps, elem_dep

Specify inter-element dependencies. If all elements at indexes which
match REGEX1 match SCHEMA1, then all elements at indexes which match
REGEX2 must match SCHEMA2.

Examples (in YAML):

 - hash
 - elem_deps: [[ password, [str, {set: 1}], password_confirmation, [str, {set: 1}] ]]

The above says: key 'password_confirmation' is required if 'password' is set.

 - hash
 - elem_deps: [[ province, [str, {set: 1, is: 'Outside US'}],
                 zipcode,  [str, {set: 0}] ],
               [ province, [str, {set: 1, not: 'Outside US'}],
                 zipcode,  [str, {set: 1}] ]
              ]

The above says: if province is set to 'Outside US', then zipcode must not be
specified. Otherwise if province is set to US states, zipcode is required.

 - array
 - elem_deps:
     - ['^0$',   [str, {set: 1, one_of: [int, integer]}], 
        '[1-9]', [hash, {set: 1, allowed_keys: [is, not, min, max]}]]
     - ['^0$',   [str, {set: 1, one_of: [str, string ]}], 
        '[1-9]', [hash, {set: 1, allowed_keys: [is, not, min, max, minlen, maxlen]}]]
     - ['^0$',   [str, {set: 1, one_of: [bool        ]}], 
        '[1-9]', [hash, {set: 1, allowed_keys: [is, not]}]]

The above says: if first element of array is int/integer, then the
following elements must be hash with. And so on if first element is
str/string, or bool.

Note: You need to be careful with undef, because it matches all schema
unless set=>1/required=>1 is specified.

=head1 AUTHOR

  Steven Haryanto <stevenharyanto@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2009 by Steven Haryanto.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

