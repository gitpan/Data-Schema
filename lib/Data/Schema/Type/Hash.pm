package Data::Schema::Type::Hash;
our $VERSION = '0.134';


# ABSTRACT: Type handler for hash ('hash')


use Moose;
extends 'Data::Schema::Type::Base';
with 
    'Data::Schema::Type::Comparable', 
    'Data::Schema::Type::Scalar', # for 'deps' only actually
    'Data::Schema::Type::HasElement';
use Storable qw/freeze/;

# see note in Array.pm on why we use Storable's freeze(). basically for speed.
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
    scalar keys %$data;
}

sub _emitpl_length {
    my ($self, $data) = @_;
    '(scalar keys %'.$data.')';
}

sub _element {
    my ($self, $data, $idx) = @_;
    $data->{$idx};
}

sub _emitpl_element {
    my ($self, $data, $idx, $lit) = @_;
    '('.$data."->{".($lit ? $idx : $self->_dump($idx))."})";
}

sub _indexes {
    my ($self, $data) = @_;
    keys %$data;
}

sub _emitpl_indexes {
    my ($self, $data) = @_;
    '(keys %'.$data.')';
}

sub handle_pre_check_attrs {
    my ($self, $data) = @_;
    if (ref($data) ne 'HASH') {
        $self->validator->data_error("must be a hash");
        return;
    }
    1;
}

sub emitpl_pre_check_attrs {
    my ($self) = @_;
    my $perl = '';

    $perl .= $self->validator->emitpl_require("Storable");
    $perl .= 'if (ref($data) ne "HASH") { '.$self->validator->emitpl_data_error("must be a hash").'; pop @$schemapos; last L1 }'."\n";
    $perl;
}

my %early_attrs = map {$_=>1} qw(allow_extra_keys);

sub sort_attr_hash_keys {
    my ($self, $attrhash) = @_;
    sort {($early_attrs{$a} ? 0:1) <=> ($early_attrs{$b} ? 0:1)} keys %$attrhash;
}



sub chkarg_attr_keys_match {
    my ($self, $arg, $name) = @_;
    $self->chkarg_r_regex($arg, $name);
}

sub handle_attr_keys_match {
    my ($self, $data, $arg) = @_;
    $self->_for_each_element($data, $arg,
                             sub {
                                (!ref($_[0]) && $_[0] =~ qr/$_[2]/) ?
                                '' :
                                "key must match regex $_[2]"
                             });
}

sub emitpl_attr_keys_match {
    my ($self, $arg) = @_;
    $self->_emitpl_for_each_element($arg,
'unless (!ref($k) && $k =~ qr/$arg/) { $err = "key must match regex $arg" }'
    );
}

Data::Schema::Type::Base::__make_attr_alias(keys_match => qw/allowed_keys_regex/);


sub chkarg_attr_keys_not_match { chkarg_attr_keys_match(@_) }

sub handle_attr_keys_not_match {
    my ($self, $data, $arg) = @_;
    $self->_for_each_element($data, $arg,
                             sub {
                                (!ref($_[0]) && $_[0] !~ qr/$_[2]/) ?
                                '' :
                                "key must not match regex $_[2]"
                             });
}

sub emitpl_attr_keys_not_match {
    my ($self, $arg) = @_;
    $self->_emitpl_for_each_element($arg,
'unless (!ref($k) && $k !~ qr/$arg/) { $err = "key must not match regex $arg" }'
    );
}

Data::Schema::Type::Base::__make_attr_alias(keys_not_match => qw/forbidden_keys_regex/);


sub chkarg_attr_keys_one_of {
    my ($self, $arg, $name) = @_;
    $self->chkarg_r_array_of_str($arg, $name);
}

sub handle_attr_keys_one_of {
    my ($self, $data, $arg) = @_;
    $self->_for_each_element($data, $arg,
                             sub {
                                # XXX early exit from grep
                                (grep {$_[0] eq $_} @$arg) ?
                                '' :
                                (@$arg ==1 ?
                                 "key must be $arg->[0]" :
                                 @$arg < 10 ?
                                 "key must be one of @$arg" :
                                 "key does not belong to list of valid keys")
                             });
}

sub emitpl_attr_keys_one_of {
    my ($self, $arg) = @_;
    $self->_emitpl_for_each_element($arg,
'unless (grep {$k eq $_} @$arg) { # XXX early exit from grep
    if (@$arg ==1) { $err = "key must be $arg->[0]" }
    elsif (@$arg < 10) { $err = "key must be one of @$arg" }
    else { $err = "key does not belong to list of valid keys" }
}'
    );
}

Data::Schema::Type::Base::__make_attr_alias(keys_one_of => qw/allowed_keys/);


sub chkarg_attr_values_one_of {
    my ($self, $arg, $name) = @_;
    $self->chkarg_r_array($arg, $name);
}

sub handle_attr_values_one_of {
    my ($self, $data, $arg) = @_;
    $self->_for_each_element($data, $arg,
                             sub {
                                # XXX early exit
                                (grep {defined($_[1]) && (ref($_[1]) ? $self->_equal($_[1], $_) : ($_[1] eq $_))} @$arg) ?
                                '' :
                                # XXX complex value must be dumped
                                (@$arg ==1 ?
                                 "value must be ".$self->_dump($arg->[0]) :
                                 @$arg < 10 ?
                                 "value must be one of ".$self->_dump($arg) :
                                 "values does not belong to list of valid values")
                             });
}

sub emitpl_attr_values_one_of {
    my ($self, $arg) = @_;
    $self->_emitpl_for_each_element($arg,
'unless (grep {defined($v) && (ref($v) ? '.$self->_emitpl_equal('$v', '$_', 1).' : ($v eq $_))} @$arg) { # XXX early exit from grep
    if (@$arg ==1) { $err = "value must be ".'.$self->_emitpl_dump('$arg->[0]', 1).' }
    elsif (@$arg < 10) { $err = "key must be one of ".'.$self->_emitpl_dump('$arg', 1).' }
    else { $err = "key does not belong to list of valid keys" }
}'
    );
}

Data::Schema::Type::Base::__make_attr_alias(values_one_of => qw/allowed_values/);


sub chkarg_attr_required_keys {
    my ($self, $arg, $name) = @_;
    $self->chkarg_r_array_of_str($arg, $name);
}

sub handle_attr_required_keys {
    my ($self, $data, $arg) = @_;
    my %checked_keys = map {$_=>0} @$arg;

    foreach my $k (keys %$data) {
        if (grep { $k eq $_ } @$arg) {
            $checked_keys{$k}++ if exists($data->{$k});
        }
    }
    my @missing_keys = grep {!$checked_keys{$_}} keys %checked_keys;
    if (@missing_keys) {
        $self->validator->data_error("missing keys: ".join(", ", @missing_keys));
        return 0;
    }
    1;
}

sub emitpl_attr_required_keys {
    my ($self, $arg) = @_;
    my $perl = '';

    $perl .= $self->validator->emitpl_my('%checked_keys', '@arg', '@missing_keys');
    $perl .= '@arg = ('.join(", ", map { $self->_perl($_) } @$arg).");\n";
    $perl .= '%checked_keys = map {$_=>0} @arg'.";\n";
    $perl .= 'foreach my $k (keys %$data) {'."\n";
    $perl .= '    if (grep { $k eq $_ } @arg) {'."\n";
    $perl .= '        $checked_keys{$k}++ if exists($data->{$k});'."\n";
    $perl .= '    }'."\n";
    $perl .= '}'."\n";
    $perl .= '@missing_keys = grep {!$checked_keys{$_}} keys %checked_keys;'."\n";
    $perl .= 'if (@missing_keys) { '.$self->validator->emitpl_data_error('"missing keys: ".join(", ", @missing_keys)', 1)." }\n";
    $perl;
}


sub chkarg_attr_required_keys_regex {
    my ($self, $arg, $name) = @_;
    $self->chkarg_r_regex($arg, $name);
}

sub handle_attr_required_keys_regex {
    my ($self, $data, $arg) = @_;
    my $found;

    foreach my $k (keys %$data) {
        if ($k =~ qr/$arg/) { $found++; last }
    }
    if (!$found) {
        $self->validator->data_error("no keys matching $arg found");
    }
    1;
}

sub emitpl_attr_required_keys_regex {
    my ($self, $arg) = @_;
    my $perl = '';

    $perl .= $self->validator->emitpl_my('$found', '$arg');
    $perl .= '$arg = '.$self->_perl($arg).";\n";
    $perl .= 'foreach my $k (keys %$data) {'."\n";
    $perl .= '    if ($k =~ qr/$arg/) { $found++; last }'."\n";
    $perl .= '}'."\n";
    $perl .= 'if (!$found) { '.$self->validator->emitpl_data_error('"no keys matching $arg found"', 1)." }\n";
    $perl;
}


sub chkarg_attr_keys {
    my ($self, $arg, $name) = @_;
    $self->chkarg_r_hash($arg, $name, 0, 0,
                         sub {
                             my ($arg, $name) = @_;
                             $self->chkarg_r_str($arg, $name);
                         },
                         sub {
                             my ($arg, $name) = @_;
                             $self->chkarg_r_schema($arg, $name);
                         }
                     );
}

sub handle_attr_keys {
    my ($self, $data, $arg) = @_;
    my $ds = $self->validator;
    my $has_err = 0;

    my $allow_extra0 = $ds->stash->{allow_extra_hash_keys};
    my $allow_extra =  defined($allow_extra0) ? $allow_extra0 :
        $ds->config->allow_extra_hash_keys;

    push @{ $ds->data_pos }, '';
    foreach my $k (keys %$data) {
        if (!exists $arg->{$k}) {
            next if $allow_extra;
            $ds->data_error("key `$k' not allowed");
            $has_err++;
        } else {
            $ds->data_pos->[-1] = $k;
            push @{ $ds->schema_pos }, $k;
            if (!$ds->_validate($data->{$k}, $arg->{$k})) {
                $has_err++;
            }
            pop @{ $ds->schema_pos };
        }
        last if $ds->too_many_errors;
    }
    pop @{ $ds->data_pos };
    !$has_err;
}

sub emitpl_attr_keys {
    my ($self, $arg) = @_;
    my $ds = $self->validator;
    my $perl = '';

    $perl .= $ds->emitpl_my('$allow_extra_keys');
    $perl .= '$allow_extra_keys //= 1; # from DS config'."\n" if $ds->config->allow_extra_hash_keys;

    my %schemas;
    for my $k (keys %$arg) {
	my ($code, $csubname) = $ds->emitpls_sub($arg->{$k});
	$perl .= $code;
	$schemas{$k} = $csubname;
    }

    $perl .= $ds->emitpl_my('%schemas');
    $perl .= '%schemas = ('.join(", ", map { $self->_perl($_) . ' => \&' . $schemas{$_} } keys %schemas).");\n";
    $perl .= 'push @$datapos, "";'."\n";
    $perl .= 'push @$schemapos, "";'."\n";
    $perl .= 'foreach my $k (keys %$data) {'."\n";
    $perl .= '    if (!exists $schemas{$k}) {'."\n";
    $perl .= '        if ($allow_extra_keys) {'."\n";
    $perl .= '            next;'."\n";
    $perl .= '        } else {'."\n";
    $perl .= '            pop @$schemapos;'."\n";
    $perl .= '            '.$ds->emitpl_data_error('"key `$k` not allowed"', 1)."\n";
    $perl .= '            push @$schemapos, "";'."\n";
    $perl .= '        }'."\n";
    $perl .= '    } else {'."\n";
    $perl .= '        $datapos->[-1] = $k;'."\n";
    $perl .= '        $schemapos->[-1] = $k;'."\n";
    $perl .= '        my ($suberrors, $subwarnings) = $schemas{$k}($data->{$k}, $datapos, $schemapos);'."\n";
    $perl .= '        '.$ds->emitpl_push_errwarn();
    $perl .= '    }'."\n";
    $perl .= '}'."\n";
    $perl .= 'pop @$datapos;'."\n";
    $perl .= 'pop @$schemapos;'."\n";
    $perl;
}


sub chkarg_attr_keys_of {
    my ($self, $arg, $name) = @_;
    $self->chkarg_r_schema($arg, $name);
}

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

sub emitpl_attr_keys_of {
    my ($self, $arg) = @_;
    my $ds = $self->validator;
    my $perl = '';

    my ($code, $csubname) = $ds->emitpls_sub($arg);
    $perl .= $code;

    $perl .= 'push @$datapos, "";'."\n";
    $perl .= 'foreach my $k (keys %$data) {'."\n";
    $perl .= '    $datapos->[-1] = $k;'."\n";
    $perl .= '    my ($suberrors, $subwarnings) = '.$csubname.'($k, $datapos, $schemapos);'."\n";
    $perl .= '    '.$ds->emitpl_push_errwarn();
    $perl .= '}'."\n";
    $perl .= 'pop @$datapos;'."\n";
    $perl;
}

Data::Schema::Type::Base::__make_attr_alias(keys_of => qw/all_keys/);


Data::Schema::Type::Base::__make_attr_alias(all_elements => qw/of all_values values_of/);


sub chkarg_attr_some_of {
    my ($self, $arg, $name) = @_;
    $self->chkarg_r_array($arg, $name, 0, 0,
                          sub {
                              my ($arg, $name) = @_;
                              return unless $self->chkarg_r_array(@_, 4, 4);
                              return unless $self->chkarg_r_schema($arg->[0], "$name/0");
                              return unless $self->chkarg_r_schema($arg->[1], "$name/1");
                              return unless $self->chkarg_r_int($arg->[2], "$name/2");
                              return unless $self->chkarg_r_int($arg->[3], "$name/3");
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
            $ds->data_error("hash must contain at least $a pairs of types $x => $y");
            $has_err++;
            last if $ds->too_many_errors;
        }
        if ($b != -1 && $m > $b) {
            my $x = !ref($r->[0]) ? $r->[0] : ref($r->[0]) eq 'ARRAY' ? "[$r->[0][0] => ...]" : "{type=>$r->[0]{type}, ...}";
            my $y = !ref($r->[1]) ? $r->[1] : ref($r->[1]) eq 'ARRAY' ? "[$r->[1][0] => ...]" : "{type=>$r->[1]{type}, ...}";
            $ds->data_error("hash must contain at most $b pairs of types $x => $y");
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
    my $ds = $self->validator;
    my $perl = '';

    my @arg;
    for my $i ((0..@$arg-1)) {
	my $ksch = $arg->[$i][0];
	my $vsch = $arg->[$i][1];
	my $ktstr = !ref($ksch) ? $ksch : ref($ksch) eq "ARRAY" ? "($ksch->[0], ...)" : "($ksch->{type}, ...)";
	my $vtstr = !ref($vsch) ? $vsch : ref($vsch) eq "ARRAY" ? "($vsch->[0], ...)" : "($vsch->{type}, ...)";
	my ($kcode, $kcsubname) = $ds->emitpls_sub($ksch);
	my ($vcode, $vcsubname) = $ds->emitpls_sub($vsch);
	$perl .= $kcode . $vcode;
	push @arg, [$kcsubname, $vcsubname, $arg->[$i][2]+0, $arg->[$i][3]+0, $ktstr, $vtstr];
    }

    $perl .= $self->validator->emitpl_my('@arg');
    $perl .= '@arg = ('.join(", ", map {"[\\&$_->[0], \\&$_->[1], $_->[2], $_->[3], '$_->[4]', '$_->[5]']"} @arg).");\n";
    $perl .= $self->validator->emitpl_my('@num_valid');
    $perl .= '@num_valid = map {0} 1..@arg;'."\n";

    $perl .= $self->validator->emitpl_my('$j');
    $perl .= '$j=0;'."\n";
    $perl .= 'for my $r (@arg) {'."\n";
    $perl .= '    for my $k (keys %$data) {'."\n";
    $perl .= '        my ($ksuberrors, $ksubwarnings) = $r->[0]($k);'."\n";
    $perl .= '        my ($vsuberrors, $vsubwarnings) = $r->[1]($data->{$k});'."\n";
    $perl .= '        if (!@$ksuberrors && !@$vsuberrors) { $num_valid[$j]++ }'."\n";
    $perl .= '    }'."\n";
    $perl .= '    $j++;'."\n";
    $perl .= '}'."\n";
    #$perl .= 'print Data::Dumper::Dumper(\@num_valid);'."\n";

    $perl .= '$j=0;'."\n";
    $perl .= 'push @$schemapos, -1;'."\n";
    $perl .= 'for my $r (@arg) {'."\n";
    $perl .= '    $schemapos->[-1] = $j;'."\n";
    $perl .= '    my ($kt, $vt, $a, $b, $m) = ($r->[4], $r->[5], $r->[2], $r->[3], $num_valid[$j]);'."\n";
    $perl .= '    my $err = ($a != -1 && $m < $a) ? "at least $a" : ($b != -1 && $m > $b) ? "at most $b" : "";'."\n";
    $perl .= '    if ($err) {'."\n";
    $perl .= '    '.$self->validator->emitpl_data_error('"hash must contain $err pairs of ($kt, $vt)"', 1)."\n";
    $perl .= "    }\n";
    $perl .= '    $j++;'."\n";
    $perl .= "}\n";
    $perl .= 'pop @$schemapos;'."\n";
    $perl;
}


sub chkarg_attr_keys_regex {
    my ($self, $arg, $name) = @_;
    $self->chkarg_r_hash($arg, $name, 0, 0,
                         sub {
                             $self->chkarg_r_regex(@_);
                         },
                         sub {
                             $self->chkarg_r_schema(@_);
                         }
                     );
}

sub handle_attr_keys_regex {
    my ($self, $data, $arg) = @_;
    my $ds = $self->validator;
    my $has_err = 0;

    my $allow_extra0 = $ds->stash->{allow_extra_hash_keys};
    my $allow_extra =  defined($allow_extra0) ? $allow_extra0 :
        $ds->config->allow_extra_hash_keys;

    push @{ $ds->data_pos }, '';
    for my $k (keys %$data) {
        $ds->data_pos->[-1] = $k;
	my $found;
        for my $ks (keys %$arg) {
            next unless $k =~ qr/$ks/;
            $found++;
	    push @{ $ds->schema_pos }, $ks;
            if (!$ds->_validate($data->{$k}, $arg->{$ks})) {
                $has_err++;
            }
            pop @{ $ds->schema_pos };
            last if $ds->too_many_errors;
        }
	if (!$found && !$allow_extra) {
	    $has_err++;
	    $ds->data_error("invalid key");
	}
        last if $ds->too_many_errors;
    }
    pop @{ $ds->data_pos };
    !$has_err;
}

sub emitpl_attr_keys_regex {
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

    $perl .= $ds->emitpl_my('$allow_extra_keys');
    $perl .= '$allow_extra_keys //= 1; # from DS config'."\n" if $ds->config->allow_extra_hash_keys;

    $perl .= $ds->emitpl_my('@arg');
    $perl .= '@arg = ('.join(", ", map {"[".$self->_dump($_->[0]).", \\&$_->[1]]"} @arg).");\n";

    $perl .= 'push @$datapos, "";'."\n";
    $perl .= 'push @$schemapos, "";'."\n";
    $perl .= $ds->emitpl_my('$found');
    $perl .= 'for my $k (keys %$data) {'."\n";
    $perl .= '    $found = 0;'."\n";
    $perl .= '    $datapos->[-1] = $k;'."\n";
    $perl .= '    for my $r (@arg) {'."\n";
    $perl .= '        $schemapos->[-1] = $r->[0];'."\n";
    $perl .= '        next unless $k =~ qr/$r->[0]/;'."\n";
    $perl .= '        $found++;'."\n";
    $perl .= '        my ($suberrors, $subwarnings) = $r->[1]($data->{$k}, $datapos, $schemapos);'."\n";
    $perl .= '        '.$ds->emitpl_push_errwarn();
    $perl .= '    }'."\n";
    $perl .= '    if (!$found && !$allow_extra_keys) { '.$ds->emitpl_data_error('"invalid key `$k`"', 1)." }\n";
    $perl .= '}'."\n";
    $perl .= 'pop @$datapos;'."\n";
    $perl .= 'pop @$schemapos;'."\n";
    $perl;
}


sub chkarg_attr_values_match {
    my ($self, $arg, $name) = @_;
    $self->chkarg_r_regex($arg, $name);
}

sub handle_attr_values_match {
    my ($self, $data, $arg) = @_;
    $self->_for_each_element($data, $arg,
                             sub {
                                (defined($_[1]) && !ref($_[1]) && $_[1] =~ qr/$_[2]/) ?
                                '' :
                                "value ($_[1]) must match regex $_[2]"
                             });
}

sub emitpl_attr_values_match {
    my ($self, $arg) = @_;
    $self->_emitpl_for_each_element($arg,
'unless (defined($v) && !ref($v) && $v =~ qr/$arg/) { $err = "value ($v) must match regex $arg" }'
    );
}

Data::Schema::Type::Base::__make_attr_alias(values_match => qw/allowed_values_regex/);


sub chkarg_attr_values_not_match { chkarg_attr_values_match(@_) }

sub handle_attr_values_not_match {
    my ($self, $data, $arg) = @_;
    $self->_for_each_element($data, $arg,
                             sub {
                                (defined($_[1]) && !ref($_[1]) && $_[1] !~ qr/$_[2]/) ?
                                '' :
                                "value ($_[1]) must not match regex $_[2]"
                             });
}

sub emitpl_attr_values_not_match {
    my ($self, $arg) = @_;
    $self->_emitpl_for_each_element($arg,
'unless (defined($v) && !ref($v) && $v !~ qr/$arg/) { $err = "value ($v) not must match regex $arg" }'
    );
}

Data::Schema::Type::Base::__make_attr_alias(values_not_match => qw/forbidden_values_regex/);


Data::Schema::Type::Base::__make_attr_alias(element_deps => qw/key_deps key_dep/);


sub chkarg_attr_allow_extra_keys {
    my ($self, $arg, $name) = @_;
    $self->chkarg_r_bool($arg, $name);
}

sub handle_attr_allow_extra_keys {
    my ($self, $data, $arg) = @_;
    $self->validator->stash->{allow_extra_hash_keys} = $arg ? 1:0;
}

sub emitpl_attr_allow_extra_keys {
    my ($self, $arg) = @_;
    my $perl = '';

    #not needed?#$self->validator->stash->{allow_extra_hash_keys} = $a;
    $perl .= $self->validator->emitpl_my('$allow_extra_keys');
    $perl .= '$allow_extra_keys = '.($arg ? 1:0)."; # from schema\n";
}


sub chkarg_attr_conflicting_keys {
    my ($self, $arg, $name) = @_;
    $self->chkarg_r_array($arg, $name, 0, 0,
                          sub {
                              return unless $self->chkarg_r_array_of_str(@_);
                              1;
                          }
                      );
}

sub handle_attr_conflicting_keys {
    my ($self, $data, $arg) = @_;
    my $has_err = 0;
    my $ds = $self->validator;

    push @{ $ds->schema_pos }, -1;
  A3:
    for my $i (0..scalar(@$arg)-1) {
        $ds->schema_pos->[-1] = $i;
        my $group = $arg->[$i];
        my @m;
      G3:
        for (@$group) {
            push @m, $_ if exists($data->{$_});
            if (@m > 1) {
                $has_err++;
                $ds->data_error("$m[0] conflicts with $m[1]");
                last A3 if $ds->too_many_errors;
                last G3;
            }
        }
    }
    pop @{ $ds->schema_pos };
    !$has_err;
}

sub emitpl_attr_conflicting_keys {
    my ($self, $arg) = @_;
    my $ds = $self->validator;
    my $perl = '';

    $perl .= $ds->emitpl_my('$arg');
    $perl .= '$arg = '.$self->_perl($arg).";\n";
    $perl .= 'push @$schemapos, -1;'."\n";
    $perl .= 'for my $i (0..scalar(@$arg)-1) {'."\n";
    $perl .= '    $schemapos->[-1] = $i;'."\n";
    $perl .= '    my $group = $arg->[$i];'."\n";
    $perl .= '    my @m;'."\n";
    $perl .= '    G3: for (@$group) {'."\n";
    $perl .= '        push @m, $_ if exists($data->{$_});'."\n";
    $perl .= '        if (@m > 1) {'."\n";
    $perl .= '            '.$ds->emitpl_data_error('"$m[0] conflicts with $m[1]"', 1)."\n";
    $perl .= '            last G3;'."\n";
    $perl .= '        }'."\n";
    $perl .= '    }'."\n";
    $perl .= '}'."\n";
    $perl .= 'pop @$schemapos;'."\n";
    $perl;
}


sub chkarg_attr_conflicting_keys_regex {
    my ($self, $arg, $name) = @_;
    $self->chkarg_r_array($arg, $name, 0, 0,
                          sub {
                              return unless $self->chkarg_r_array_of_regex(@_);
                              1;
                          }
                      );
}

sub handle_attr_conflicting_keys_regex {
    my ($self, $data, $arg) = @_;
    my $has_err = 0;
    my $ds = $self->validator;

    push @{ $ds->schema_pos }, -1;
  A4:
    for my $i (0..scalar(@$arg)-1) {
        $ds->schema_pos->[-1] = $i;
        my $group = $arg->[$i];
        my %m;
      G4:
        for my $re (@$group) {
            for (keys %$data) {
                $m{$re}++ if /$re/;
                if (keys(%m) > 1) {
                    $has_err++;
                    $ds->data_error("Keys conflict: ".$self->_dump([keys %m]));
                    last A4 if $ds->too_many_errors;
                    last G4;
                }
            }
        }
    }
    pop @{ $ds->schema_pos };
    !$has_err;
}

sub emitpl_attr_conflicting_keys_regex {
    my ($self, $arg) = @_;
    my $ds = $self->validator;
    my $perl = '';

    $perl .= $ds->emitpl_my('$arg');
    $perl .= '$arg = '.$self->_perl($arg).";\n";
    $perl .= 'push @$schemapos, -1;'."\n";
    $perl .= 'for my $i (0..scalar(@$arg)-1) {'."\n";
    $perl .= '    $schemapos->[-1] = $i;'."\n";
    $perl .= '    my $group = $arg->[$i];'."\n";
    $perl .= '    my %m;'."\n";
    $perl .= '    G4: for my $re (@$group) {'."\n";
    $perl .= '        for (keys %$data) {'."\n";
    $perl .= '            $m{$re}++ if /$re/;'."\n";
    $perl .= '            if (keys(%m) > 1) {'."\n";
    $perl .= '                '.$ds->emitpl_data_error('"Keys conflict: ".'.$self->_emitpl_dump('keys %m', 1), 1)."\n";
    $perl .= '                last G4;'."\n";
    $perl .= '            }'."\n";
    $perl .= '        }'."\n";
    $perl .= '    }'."\n";
    $perl .= '}'."\n";
    $perl .= 'pop @$schemapos;'."\n";
    $perl;
}


sub chkarg_attr_codependent_keys { chkarg_attr_conflicting_keys(@_) }

sub handle_attr_codependent_keys {
    my ($self, $data, $arg) = @_;
    my $has_err = 0;
    my $ds = $self->validator;

    push @{ $ds->schema_pos }, -1;
  A1:
    for my $i (0..scalar(@$arg)-1) {
        $ds->schema_pos->[-1] = $i;
        my $group = $arg->[$i];
        my @m;
        for (@$group) {
            push @m, $_ if exists($data->{$_});
        }
        if (@m > 0 && @m < @$group) {
            $has_err++;
            $ds->data_error("keys ".$self->_dump($group)." must all exist or none exists");
            last A1 if $ds->too_many_errors;
        }
    }
    pop @{ $ds->schema_pos };
    !$has_err;
}

sub emitpl_attr_codependent_keys {
    my ($self, $arg) = @_;
    my $ds = $self->validator;
    my $perl = '';

    $perl .= $ds->emitpl_my('$arg');
    $perl .= '$arg = '.$self->_perl($arg).";\n";
    $perl .= 'push @$schemapos, -1;'."\n";
    $perl .= 'for my $i (0..scalar(@$arg)-1) {'."\n";
    $perl .= '    $schemapos->[-1] = $i;'."\n";
    $perl .= '    my $group = $arg->[$i];'."\n";
    $perl .= '    my @m;'."\n";
    $perl .= '    for (@$group) {'."\n";
    $perl .= '        push @m, $_ if exists($data->{$_});'."\n";
    $perl .= '    }'."\n";
    $perl .= '    if (@m > 0 && @m < @$group) {'."\n";
    $perl .= '        '.$ds->emitpl_data_error('"keys ".'.$self->_emitpl_dump('$group', 1).'." must all exist or none exists"', 1)."\n";
    $perl .= '    }'."\n";
    $perl .= '}'."\n";
    $perl .= 'pop @$schemapos;'."\n";
    $perl;
}


sub chkarg_attr_codependent_keys_regex { chkarg_attr_conflicting_keys_regex(@_) }

sub handle_attr_codependent_keys_regex {
    my ($self, $data, $arg) = @_;
    my $has_err = 0;
    my $ds = $self->validator;

    push @{ $ds->schema_pos }, -1;
  A2:
    for my $i (0..scalar(@$arg)-1) {
        $ds->schema_pos->[-1] = $i;
        my $group = $arg->[$i];
        my %m;
        for my $re (@$group) {
            for (keys %$data) {
                $m{$re}++ if /$re/;
            }
        }
        if (keys(%m) > 0 && keys(%m) < @$group) {
            $has_err++;
            $ds->data_error("keys which match ".$self->_dump($group)." must all exist or none exists");
            last A2 if $ds->too_many_errors;
        }
    }
    pop @{ $ds->schema_pos };
    !$has_err;
}

sub emitpl_attr_codependent_keys_regex {
    my ($self, $arg) = @_;
    my $ds = $self->validator;
    my $perl = '';

    $perl .= $ds->emitpl_my('$arg');
    $perl .= '$arg = '.$self->_perl($arg).";\n";
    $perl .= 'push @$schemapos, -1;'."\n";
    $perl .= 'for my $i (0..scalar(@$arg)-1) {'."\n";
    $perl .= '    $schemapos->[-1] = $i;'."\n";
    $perl .= '    my $group = $arg->[$i];'."\n";
    $perl .= '    my %m;'."\n";
    $perl .= '    for my $re (@$group) {'."\n";
    $perl .= '        for (keys %$data) {'."\n";
    $perl .= '            $m{$re}++ if /$re/;'."\n";
    $perl .= '        }'."\n";
    $perl .= '    }'."\n";
    $perl .= '    if (keys(%m) > 0 && keys(%m) < @$group) {'."\n";
    $perl .= '        '.$ds->emitpl_data_error('"keys which match ".'.$self->_emitpl_dump('$group', 1).'." must all exist or none exists"', 1)."\n";
    $perl .= '    }'."\n";
    $perl .= '}'."\n";
    $perl .= 'pop @$schemapos;'."\n";
    $perl;
}

sub short_english {
    "hash";
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

__PACKAGE__->meta->make_immutable;
no Moose;
1;

__END__
=pod

=head1 NAME

Data::Schema::Type::Hash - Type handler for hash ('hash')

=head1 VERSION

version 0.134

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

=head1 TYPE ATTRIBUTES

Hashes are Comparable and HasElement, so you might want to consult the docs of
those roles to see what type attributes are available.

Aside from those, hash also has these type attributes:

=head2 keys_match => REGEX

Aliases: C<allowed_keys_regex>

Require that all hash keys match a regular expression.

=head2 keys_not_match => REGEX

Aliases: C<forbidden_keys_regex>

This is the opposite of B<keys_match>, forbidding all hash keys from matching a
regular expression.

=head2 keys_one_of => [VALUE, ...]

Aliases: allowed_keys

Specify that all hash keys must belong to a list of specified values.

For example (in YAML):

 [hash, {allowed_keys: [name, age, address]}]

This specifies that only keys 'name', 'age', 'address' are allowed (but none are
required).

=head2 values_one_of => [VALUE, ...]

Aliases: allowed_values

Specify that all hash values must belong to a list of specified values.

For example (in YAML):

 [hash, {allowed_values: [1, 2, 3, 4, 5]}]

=head2 required_keys => [KEY1, KEY2. ...]

Require that certain keys exist in the hash.

=head2 required_keys_regex => REGEX

Require that keys matching a regular expression exist in the hash

=head2 keys => {KEY=>SCHEMA1, KEY2=>SCHEMA2, ...}

Specify schema for hash keys (hash values, actually).

For example (in YAML):

 [hash, {keys: { name: str, age: [int, {min: 0}] } }]

This specifies that the value for key 'name' must be a string, and the value for
key 'age' must be a positive integer.

=head2 keys_of => SCHEMA

Aliases: all_keys

Specify a schema for all hash keys.

For example (in YAML):

 [hash, {keys_of: int}]

This specifies that all hash keys must be ints.

=head2 of => SCHEMA

Aliases: all_values, values_of, all_elements, all_elems, all_elem

Specify a schema for all hash values.

For example (in YAML):

 [hash, {of: int}]

This specifies that all hash values must be ints.

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

=head2 keys_regex => {REGEX1=>SCHEMA1, REGEX2=>SCHEMA2, ...}

Similar to B<keys> but instead of specifying schema for each key, we specify
schema for each set of keys using regular expression.

For example:

 [hash=>{keys_regex=>{ '\d'=>"int", '^\D+$'=>"str" }}]

This specifies that for all keys which contain a digit, the values must be int,
while for all non-digit-containing keys, the values must be str. Example: {
a=>"a", a1=>1, a2=>-3, b=>1 }. Note: b=>1 is valid because 1 is a valid str.

This attribute also obeys allow_extra_hash_keys setting, like C<keys>.

Example:

 my $sch = [hash=>{keys_regex=>{'^\w+$'=>[str=>{match=>'^\w+$'}]}}];

 my $ds1 = Data::Schema->new(config=>{allow_extra_hash_keys=>1});
 $ds1->validate({"contain space" => "contain space"}, $sch); # valid
 my $ds2 = Data::Schema->new(); # default allow_extra_hash_keys is 0
 $ds2->validate({"contain space" => "contain space"}, $sch); # invalid, no keys matches keys_regex

=head2 values_match => REGEX

Aliases: C<allowed_values_regex>

Specifies that all values must be scalar and match regular expression.

=head2 values_not_match => REGEX

Aliases: C<forbidden_values_regex>

The opposite of B<values_match>, requires that all values not match regular
expression (but must be a scalar).

=head2 key_deps => SCHEMA

Aliases: key_dep, element_deps, elem_deps, element_dep, elem_dep

Specify inter-element dependency. See
L<Data::Schema::Type::HasElement> for details.

=head2 allow_extra_keys => BOOL

Overrides B<allow_extra_hash_keys> config. Useful in subschemas, example (in
YAML):

 # in schemadir/address.yaml
 - hash
 - allowed_keys: [line1, line2, city, province, country, postcode]
   keys:
     line1: [str, {required: 1}]
     line2: str
     city: [str, {required: 1}]
     province: [str, {required: 1}]
     country: [str, {match: '^[A-Z]{2}$', required: 1}]
     postcode: str

 # in schemadir/us_address.yaml
 - us_address
 - allow_extra_keys: 1
 - keys:
     country: [str, {is: US}]

Without allow_extra_keys, us_address will only allow key 'country' (due to
'keys' limiting allowed hash keys to only those specified in it).

=head2 conflicting_keys => [[A, B], [C, D, E], ...]

State that A and B are conflicting keys and cannot exist together. And
so are C, D, E.

Example:

 ds_validate({C=>1      }, [hash=>{conflicting_keys=>[["C", "D", "E"]]}]); # valid
 ds_validate({C=>1, D=>1}, [hash=>{conflicting_keys=>[["C", "D", "E"]]}]); # invalid

=head2 conflicting_keys_regex => [[REGEX_A, REGEX_B], [REGEX_C, REGEX_D, REGEX_E], ...]

Just like C<conflicting_keys>, but keys are expressed using regular
expression.

=head2 codependent_keys => [[A, B], [C, D, E], ...]

State that A and B are codependent keys and must exist together. And
so are C, D, E.

Example:

 ds_validate({C=>1, D=>1      }, [hash=>{codependent_keys=>[["C", "D", "E"]]}]); # invalid
 ds_validate({C=>1, D=>1, E=>1}, [hash=>{codependent_keys=>[["C", "D", "E"]]}]); # valid

=head2 codependent_keys_regex => [[REGEX_A, REGEX_B], [REGEX_C, REGEX_D, REGEX_E], ...]

Just like C<codependent_keys>, but keys are expressed using regular expression.

=head1 AUTHOR

  Steven Haryanto <stevenharyanto@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2009 by Steven Haryanto.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

