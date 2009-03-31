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
    # one_of, 6x4 = 24
    for (qw(one_of
            is_one_of
            oneof
            is_oneof
            choice
            choices)) { # XXX enum
        valid($valid1, [$type => {$_=>[$valid1, $valid2]}], "$type:$_ 1", $ds);
        valid($valid2, [$type => {$_=>[$valid1, $valid2]}], "$type:$_ 2", $ds);
        invalid($invalid1, [$type => {$_=>[$valid1, $valid2]}], "$type:$_ 3", $ds);
        invalid($invalid2, [$type => {$_=>[$valid1, $valid2]}], "$type:$_ 4", $ds);
    }
    # isnt_one_of = 6x4 = 24
    for (qw(isnt_one_of
            not_one_of
            is_not_one_of
            isnt_oneof
            not_oneof
            is_not_oneof)) {
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
    # isnt, 3x4 = 12
    for (qw(isnt
            is_not
            not)) {
        valid($valid1, [$type => {$_=>$invalid1}], "$type:$_ 1", $ds);
        valid($valid2, [$type => {$_=>$invalid1}], "$type:$_ 2", $ds);
        invalid($invalid1, [$type => {$_=>$invalid1}], "$type:$_ 3", $ds);
        valid($invalid2, [$type => {$_=>$invalid1}], "$type:$_ 4", $ds);
    }
    # total = 62
}

sub test_min_max($$$$;$) {
    my ($type, $a, $b, $c, $ds) = @_;
    for (qw(min ge greater_or_equal_than greater_equal_than)) { # 4x3 = 12
        invalid($a, [$type => {$_=>$b}], "$type:$_ 1", $ds);
        valid($b, [$type => {$_=>$b}], "$type:$_ 2", $ds);
        valid($c, [$type => {$_=>$b}], "$type:$_ 3", $ds);
    }
    for (qw(max le less_or_equal_than less_equal_than)) { # 4x3 = 12
        valid($a, [$type => {$_=>$b}], "$type:$_ 1", $ds);
        valid($b, [$type => {$_=>$b}], "$type:$_ 2", $ds);
        invalid($c, [$type => {$_=>$b}], "$type:$_ 3", $ds);
    }
    for (qw(minex gt greater_than)) { # 3x3 = 9
        invalid($a, [$type => {$_=>$b}], "$type:$_ 1", $ds);
        invalid($b, [$type => {$_=>$b}], "$type:$_ 2", $ds);
        valid($c, [$type => {$_=>$b}], "$type:$_ 3", $ds);
    }
    for (qw(maxex lt less_than)) { # 3x3 = 9
        valid($a, [$type => {$_=>$b}], "$type:$_ 1", $ds);
        invalid($b, [$type => {$_=>$b}], "$type:$_ 2", $ds);
        invalid($c, [$type => {$_=>$b}], "$type:$_ 3", $ds);
    }
    valid($a, [$type => {between=>[$a,$b]}], "$type:between 1", $ds);
    valid($b, [$type => {between=>[$a,$b]}], "$type:between 2", $ds);
    invalid($c, [$type => {between=>[$a,$b]}], "$type:between 3", $ds);
    # total = 12+12+9+9+3 = 45
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

1;
