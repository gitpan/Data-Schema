sub _valid_invalid($$;$) {
    my ($data, $schema, $ds) = @_;
    $ds ||= Data::Schema->new;
    $ds->validate($data, $schema);
}

sub valid($$$;$) {
    my ($data, $schema, $test_name, $ds) = @_;
    my $res = _valid_invalid($data, $schema, $ds);
    ok($res && $res->{success}, $test_name);
}

sub invalid($$$;$) {
    my ($data, $schema, $test_name, $ds) = @_;
    my $res = _valid_invalid($data, $schema, $ds);
    ok($res && !$res->{success}, $test_name);
}

sub test_is_isnt_oneof($$$$$;$) {
    my ($type, $valid1, $valid2, $invalid1, $invalid2, $ds) = @_;
    # one_of, 2x4 = 8
    for (qw(one_of
            is_one_of
            )) { # XXX enum
        valid($valid1, [$type => {$_=>[$valid1, $valid2]}], "$type:$_ 1", $ds);
        valid($valid2, [$type => {$_=>[$valid1, $valid2]}], "$type:$_ 2", $ds);
        invalid($invalid1, [$type => {$_=>[$valid1, $valid2]}], "$type:$_ 3", $ds);
        invalid($invalid2, [$type => {$_=>[$valid1, $valid2]}], "$type:$_ 4", $ds);
    }
    # isnt_one_of = 2x4 = 8
    for (qw(isnt_one_of
            not_one_of
            )) {
        valid($valid1, [$type => {$_=>[$invalid1, $invalid2]}], "$type:invalid_values 1", $ds);
        valid($valid2, [$type => {$_=>[$invalid1, $invalid2]}], "$type:invalid_values 2", $ds);
        invalid($invalid1, [$type => {$_=>[$invalid1, $invalid2]}], "$type:invalid_values 3", $ds);
        invalid($invalid2, [$type => {$_=>[$invalid1, $invalid2]}], "$type:invalid_values 4", $ds);
    }
    # is, 1x2 = 2
    for (qw(is)) {
        valid($valid1, [$type => {$_=>$valid1}], "$type:$_ 1", $ds);
        invalid($valid2, [$type => {$_=>$valid1}], "$type:$_ 2", $ds);
    }
    # isnt, 2x4 = 8
    for (qw(isnt
            not)) {
        valid($valid1, [$type => {$_=>$invalid1}], "$type:$_ 1", $ds);
        valid($valid2, [$type => {$_=>$invalid1}], "$type:$_ 2", $ds);
        invalid($invalid1, [$type => {$_=>$invalid1}], "$type:$_ 3", $ds);
        valid($invalid2, [$type => {$_=>$invalid1}], "$type:$_ 4", $ds);
    }
    # total = 8+8+2+8 = 26
}

sub test_min_max($$$$;$) {
    my ($type, $a, $b, $c, $ds) = @_;
    for (qw(min ge)) { # 2x3 = 6
        invalid($a, [$type => {$_=>$b}], "$type:$_ 1", $ds);
        valid($b, [$type => {$_=>$b}], "$type:$_ 2", $ds);
        valid($c, [$type => {$_=>$b}], "$type:$_ 3", $ds);
    }
    for (qw(max le)) { # 2x3 = 6
        valid($a, [$type => {$_=>$b}], "$type:$_ 1", $ds);
        valid($b, [$type => {$_=>$b}], "$type:$_ 2", $ds);
        invalid($c, [$type => {$_=>$b}], "$type:$_ 3", $ds);
    }
    for (qw(minex gt)) { # 2x3 = 6
        invalid($a, [$type => {$_=>$b}], "$type:$_ 1", $ds);
        invalid($b, [$type => {$_=>$b}], "$type:$_ 2", $ds);
        valid($c, [$type => {$_=>$b}], "$type:$_ 3", $ds);
    }
    for (qw(maxex lt)) { # 2x3 = 6
        valid($a, [$type => {$_=>$b}], "$type:$_ 1", $ds);
        invalid($b, [$type => {$_=>$b}], "$type:$_ 2", $ds);
        invalid($c, [$type => {$_=>$b}], "$type:$_ 3", $ds);
    }
    valid($a, [$type => {between=>[$a,$b]}], "$type:between 1", $ds);
    valid($b, [$type => {between=>[$a,$b]}], "$type:between 2", $ds);
    invalid($c, [$type => {between=>[$a,$b]}], "$type:between 3", $ds);
    # total = 6+6+6+6+3 = 27
}

sub test_len($$$$;$) {
    my ($type, $len1, $len2, $len3, $ds) = @_;
    # 4x3 = 12
    for(qw(minlength minlen min_length minlen)) {
        invalid($len1, [$type => {$_=>2}], "$type:$_ 1", $ds);
        valid($len2, [$type => {$_=>2}], "$type:$_ 2", $ds);
        valid($len3, [$type => {$_=>2}], "$type:$_ 3", $ds);
    }
    # 4x3 = 12
    for(qw(maxlength maxlen max_length maxlen)) {
        valid($len1, [$type => {$_=>2}], "$type:$_ 1", $ds);
        valid($len2, [$type => {$_=>2}], "$type:$_ 2", $ds);
        invalid($len3, [$type => {$_=>2}], "$type:$_ 3", $ds);
    }
    # 2x3 = 6
    for(qw(len_between length_between)) {
        valid($len1, [$type => {$_=>[1,2]}], "$type:$_ 1", $ds);
        valid($len2, [$type => {$_=>[1,2]}], "$type:$_ 2", $ds);
        invalid($len3, [$type => {$_=>[1,2]}], "$type:$_ 3", $ds);
    }
    # 2x3 = 6
    for(qw(len length)) {
        invalid($len1, [$type => {$_=>2}], "$type:$_ 1", $ds);
        valid($len2, [$type => {$_=>2}], "$type:$_ 2", $ds);
        invalid($len3, [$type => {$_=>2}], "$type:$_ 3", $ds);
    }
    # total 36
}

sub type_in_english($;$) {
    my ($schema, $ds) = @_;
    $ds ||= Data::Schema->new;
    $schema = $ds->normalize_schema($schema) unless ref($schema) eq 'HASH';
    $ds->get_type_handler($schema->{type})->type_in_english($schema);
}

sub test_type_in_english($$$;$) {
    my ($schema, $english, $test_name, $ds) = @_;
    $ds ||= Data::Schema->new;
    is(type_in_english($schema, $ds), $english, $test_name);
}

1;
