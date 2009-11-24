use Storable;
use Data::Dumper;
use strict;
use warnings;
use Carp::Always;
use Scalar::Util qw/tainted/;

$Data::Dumper::Indent = 0;
$Data::Dumper::Terse = 1;
$Data::Dumper::Sortkeys = 1;
$Data::Dumper::Purity = 0;

my $Default_DS_NoCompile;
my $Default_DS_Compile;

# test validation on 2 variant: compiled and uncompiled
sub test_validate($$;$) {
    my ($data, $schema, $ds_user) = @_;
    if (!$Default_DS_NoCompile) { $Default_DS_NoCompile = Data::Schema->new(config=>{compile=>0}) }
    if (!$Default_DS_Compile  ) { $Default_DS_Compile   = Data::Schema->new(config=>{compile=>1}) }
    my ($ds_compile, $ds_nocompile);
    if ($ds_user) {
	if ($ds_user->config->compile) {
	    $ds_compile = $ds_user;
	    $ds_nocompile = Storable::dclone($ds_user);
	    $ds_nocompile->config->compile(0);
	} else {
	    $ds_nocompile = $ds_user;
	    $ds_compile = Storable::dclone($ds_user);
	    $ds_compile->config->compile(1);
	}
	#print "ds: ".Dumper($ds_nocompile)."\n";
	#print "ds_compile  : ".Dumper($ds_compile)."\n";
    } else {
	$ds_nocompile = $Default_DS_NoCompile;
	$ds_compile   = $Default_DS_Compile;
    }
    #print "\$ds_nocompile tainted? ", tainted($ds_nocompile), "\n";
    #print "\$ds_compile tainted? ", tainted($ds_compile), "\n";
    my $res_nocompile = $ds_nocompile->validate($data, $schema);
    my $res_compile   = $ds_compile  ->validate($data, $schema);
    #print "result: ".Dumper($res_nocompile)."\n";
    #print "result (compiled): ".Dumper($res_compile)."\n";
    ($res_nocompile, $res_compile);
}

sub valid($$$;$) {
    my ($data, $schema, $test_name, $ds) = @_;
    #print "valid(".Dumper($data).", ".Dumper($schema).", '$test_name', ".($ds // "undef").")\n";
    my ($res_nocompile, $res_compile) = test_validate($data, $schema, $ds);
    ok($res_nocompile && $res_nocompile->{success}, $test_name);
    ok($res_compile   && $res_compile->{success}  , "$test_name (compiled)");
}

sub invalid($$$;$) {
    my ($data, $schema, $test_name, $ds) = @_;
    #print "invalid(".Dumper($data).", ".Dumper($schema).", '$test_name', ".($ds // "undef").")\n";
    my ($res_nocompile, $res_compile) = test_validate($data, $schema, $ds);
    ok($res_nocompile && !$res_nocompile->{success}, $test_name);
    ok($res_compile   && !$res_compile->{success}  , "$test_name (compiled)");
}

sub test_comparable($$$$$;$) {
    my ($type, $valid1, $valid2, $invalid1, $invalid2, $ds) = @_;
    for (qw(one_of
            is_one_of
            )) { # XXX enum
        valid($valid1, [$type => {$_=>[$valid1, $valid2]}], "comparable:$type:$_ 1", $ds);
        valid($valid2, [$type => {$_=>[$valid1, $valid2]}], "comparable:$type:$_ 2", $ds);
        invalid($invalid1, [$type => {$_=>[$valid1, $valid2]}], "comparable:$type:$_ 3", $ds);
        invalid($invalid2, [$type => {$_=>[$valid1, $valid2]}], "comparable:$type:$_ 4", $ds);
    }
    for (qw(isnt_one_of
            not_one_of
            )) {
        valid($valid1, [$type => {$_=>[$invalid1, $invalid2]}], "comparable:$type:$_ 1", $ds);
        valid($valid2, [$type => {$_=>[$invalid1, $invalid2]}], "comparable:$type:$_ 2", $ds);
        invalid($invalid1, [$type => {$_=>[$invalid1, $invalid2]}], "comparable:$type:$_ 3", $ds);
        invalid($invalid2, [$type => {$_=>[$invalid1, $invalid2]}], "comparable:$type:$_ 4", $ds);
    }
    for (qw(is)) {
        valid($valid1, [$type => {$_=>$valid1}], "comparable:$type:$_ 1", $ds);
        invalid($valid2, [$type => {$_=>$valid1}], "comparable:$type:$_ 2", $ds);
    }
    for (qw(isnt
            not)) {
        valid($valid1, [$type => {$_=>$invalid1}], "comparable:$type:$_ 1", $ds);
        valid($valid2, [$type => {$_=>$invalid1}], "comparable:$type:$_ 2", $ds);
        invalid($invalid1, [$type => {$_=>$invalid1}], "comparable:$type:$_ 3", $ds);
        valid($invalid2, [$type => {$_=>$invalid1}], "comparable:$type:$_ 4", $ds);
    }
}

sub test_sortable($$$$;$) {
    my ($type, $a, $b, $c, $ds) = @_;
    for (qw(min ge)) {
        invalid($a, [$type => {$_=>$b}], "sortable:$type:$_ 1", $ds);
        valid($b, [$type => {$_=>$b}], "sortable:$type:$_ 2", $ds);
        valid($c, [$type => {$_=>$b}], "sortable:$type:$_ 3", $ds);
    }
    for (qw(max le)) {
        valid($a, [$type => {$_=>$b}], "sortable:$type:$_ 1", $ds);
        valid($b, [$type => {$_=>$b}], "sortable:$type:$_ 2", $ds);
        invalid($c, [$type => {$_=>$b}], "sortable:$type:$_ 3", $ds);
    }
    for (qw(minex gt)) {
        invalid($a, [$type => {$_=>$b}], "sortable:$type:$_ 1", $ds);
        invalid($b, [$type => {$_=>$b}], "sortable:$type:$_ 2", $ds);
        valid($c, [$type => {$_=>$b}], "sortable:$type:$_ 3", $ds);
    }
    for (qw(maxex lt)) {
        valid($a, [$type => {$_=>$b}], "sortable:$type:$_ 1", $ds);
        invalid($b, [$type => {$_=>$b}], "sortable:$type:$_ 2", $ds);
        invalid($c, [$type => {$_=>$b}], "sortable:$type:$_ 3", $ds);
    }
    valid($a, [$type => {between=>[$a,$b]}], "sortable:$type:between 1", $ds);
    valid($b, [$type => {between=>[$a,$b]}], "sortable:$type:between 2", $ds);
    invalid($c, [$type => {between=>[$a,$b]}], "sortable:$type:between 3", $ds);
}

sub test_len($$$$;$) {
    my ($type, $len1, $len2, $len3, $ds) = @_;
    for(qw(minlength minlen min_length minlen)) {
        invalid($len1, [$type => {$_=>2}], "len:$type:$_ 1", $ds);
        valid($len2, [$type => {$_=>2}], "len:$type:$_ 2", $ds);
        valid($len3, [$type => {$_=>2}], "len:$type:$_ 3", $ds);
    }
    for(qw(maxlength maxlen max_length maxlen)) {
        valid($len1, [$type => {$_=>2}], "len:$type:$_ 1", $ds);
        valid($len2, [$type => {$_=>2}], "len:$type:$_ 2", $ds);
        invalid($len3, [$type => {$_=>2}], "len:$type:$_ 3", $ds);
    }
    for(qw(len_between length_between)) {
        valid($len1, [$type => {$_=>[1,2]}], "len:$type:$_ 1", $ds);
        valid($len2, [$type => {$_=>[1,2]}], "len:$type:$_ 2", $ds);
        invalid($len3, [$type => {$_=>[1,2]}], "len:$type:$_ 3", $ds);
    }
    for(qw(len length)) {
        invalid($len1, [$type => {$_=>2}], "len:$type:$_ 1", $ds);
        valid($len2, [$type => {$_=>2}], "len:$type:$_ 2", $ds);
        invalid($len3, [$type => {$_=>2}], "len:$type:$_ 3", $ds);
    }
}

sub english($;$) {
    my ($schema, $ds) = @_;
    $ds ||= Data::Schema->new;
    $schema = $ds->normalize_schema($schema) unless ref($schema) eq 'HASH';
    $ds->get_type_handler($schema->{type})->english($schema);
}

sub test_english($$$;$) {
    my ($schema, $english, $test_name, $ds) = @_;
    $ds ||= Data::Schema->new;
    is(english($schema, $ds), $english, $test_name);
}

sub test_scalar_deps($$$) {
    my ($type, $data, $attrhash1, $attrhash2) = @_;
    # 1dep, match
    valid  ($data, [$type => {deps=>[[ $type, $type ]]}], "$type:deps 1");
    valid  ($data, [$type => {deps=>[[ $type, [$type=>$attrhash1] ]]}], "$type:deps 2");
    valid  ($data, [$type => {deps=>[[ [$type=>$attrhash1], $type ]]}], "$type:deps 3");
    valid  ($data, [$type => {deps=>[[ [$type=>$attrhash1], [$type=>$attrhash1] ]]}], "$type:deps 4");
    invalid($data, [$type => {deps=>[[ [$type=>$attrhash1], [$type=>$attrhash2] ]]}], "$type:deps 5");

    # 1dep, not match, right-side schema don't matter
    valid  ($data, [$type => {deps=>[[ [$type=>$attrhash2], $type ]]}], "$type:deps 6");
    valid  ($data, [$type => {deps=>[[ [$type=>$attrhash2], [$type=>$attrhash1] ]]}], "$type:deps 7");
    valid  ($data, [$type => {deps=>[[ [$type=>$attrhash2], [$type=>$attrhash2] ]]}], "$type:deps 8");

    # 2dep, 1 match, 1 not match (right-side schema don't matter for second dep)
    valid  ($data, [$type => {deps=>[[ [$type=>$attrhash1], $type ], [ [$type=>$attrhash2], $type ]]}], "$type:deps 9a");
    valid  ($data, [$type => {deps=>[[ [$type=>$attrhash1], $type ], [ [$type=>$attrhash2], [$type=>$attrhash1] ]]}], "$type:deps 9b");
    valid  ($data, [$type => {deps=>[[ [$type=>$attrhash1], $type ], [ [$type=>$attrhash2], [$type=>$attrhash2] ]]}], "$type:deps 9c");
    valid  ($data, [$type => {deps=>[[ [$type=>$attrhash1], [$type=>$attrhash1] ], [ [$type=>$attrhash2], $type ]]}], "$type:deps 10a");
    valid  ($data, [$type => {deps=>[[ [$type=>$attrhash1], [$type=>$attrhash1] ], [ [$type=>$attrhash2], [$type=>$attrhash1] ]]}], "$type:deps 10b");
    valid  ($data, [$type => {deps=>[[ [$type=>$attrhash1], [$type=>$attrhash1] ], [ [$type=>$attrhash2], [$type=>$attrhash2] ]]}], "$type:deps 10c");
    invalid($data, [$type => {deps=>[[ [$type=>$attrhash1], [$type=>$attrhash2] ], [ [$type=>$attrhash2], $type ]]}], "$type:deps 11a");
    invalid($data, [$type => {deps=>[[ [$type=>$attrhash1], [$type=>$attrhash2] ], [ [$type=>$attrhash2], [$type=>$attrhash1] ]]}], "$type:deps 11b");
    invalid($data, [$type => {deps=>[[ [$type=>$attrhash1], [$type=>$attrhash2] ], [ [$type=>$attrhash2], [$type=>$attrhash2] ]]}], "$type:deps 11c");
}

1;
