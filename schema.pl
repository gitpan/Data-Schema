#!perl

# the DS schema of standard DS schema, with no subschema or schema
# type definition

# Perl's YAML modules currently lack merge keys feature, so it's more
# convenient to write in perl ATM

use strict;
use warnings;

my $standard_types = [qw/
    str string
    cistr cistring
    bool boolean
    hash
    array
    object obj
    int integer
    float
    either or any
    all and
/];

my $types = $standard_types;

my $re_merge_prefix = '[*+.!^-]';

my $sch_1form  = [str => {set=>1, one_of=>$types}];

my %sch_2form;
my %sch_3form;

sub build_sch_23form($$$) {
    my ($name, $aliases, $sch_attrs) = @_;

    my $sch_type = [
	str => {
	    set => 1,
	    one_of => [$name, @$aliases],
	}
	];
    
    my $sch_attrhash0 = [
	hash => {
	    set => 1,
	    keys => $sch_attrs,
	}
	];

    my $sch_attrhash = [
	hash => {
	    set => 1,
	    allowed_keys_regex => "^(?:$re_merge_prefix)?(?:" . join('|', keys %$sch_attrs) . ')$',
	    keys_regex => { map { "^(?:$re_merge_prefix)?".$_.'$' => $sch_attrs->{$_} } keys %$sch_attrs },
	}
	];

    $sch_2form{$name} = [
	array => {
	    set=>1, 
	    minlen=>1,
	    elem_regex => {
		'^0$' => $sch_type,
		'^1$' => $sch_attrhash0,
		'^([2-9]|[1-9][0-9]+)$' => $sch_attrhash,
	    },
	}
	];
    $sch_3form{$name} = [
	hash => {
	    set=>1, 
	    allowed_keys => [qw/def type attr_hashes/],
	    keys_regex => {
		#'^def$' => [hash => {set=>1, keys_match=>$re_typename, values_of=>$schema}],
		'^type$' => $sch_type,
		'^attr_hashes$' => [
		    array => {
			set => 1,
			elem_regex => {
			    '^0$' => $sch_attrhash0,
			    '[1-9]' => $sch_attrhash,
			},
		    }
		    ],
	    },
	}
	];
}

my %attrs_comparable;

$attrs_comparable{one_of}       = [array => {set=>1, of=>[any=>{set=>1}]}];
$attrs_comparable{is_one_of}    = $attrs_comparable{one_of};
$attrs_comparable{not_one_of}   = $attrs_comparable{one_of};
$attrs_comparable{isnt_one_of}  = $attrs_comparable{not_one_of};
$attrs_comparable{is}           = [any => {set=>1}];
$attrs_comparable{isnt}         = $attrs_comparable{is};
$attrs_comparable{not}          = $attrs_comparable{isnt};

my %attrs_sortable;

$attrs_sortable{min}          = [any => {set=>1}];
$attrs_sortable{ge}           = $attrs_sortable{min};
$attrs_sortable{max}          = $attrs_sortable{min};
$attrs_sortable{le}           = $attrs_sortable{max};
$attrs_sortable{minex}        = $attrs_sortable{min};
$attrs_sortable{gt}           = $attrs_sortable{minex};
$attrs_sortable{maxex}        = $attrs_sortable{min};
$attrs_sortable{lt}           = $attrs_sortable{maxex};
$attrs_sortable{between}      = [array => {set=>1, len=>2, elem=>[$attrs_sortable{min}, $attrs_sortable{max}]}];

my %attrs_num = (%attrs_comparable, %attrs_sortable);

make_sch_23form('float', [], \%attrs_num);

my %attrs_int;

make_sch_23form('int', [qw/integer/], {%attrs_num, %attrs_int});

my $sch_2form  = [array => {set=>1, 
			    elem_regex=>{ 
				'^0$' => $sch_type,
				'^1$' => $sch_attrhash0,
				'^([2-9]|[1-9][0-9]+)$' => $sch_attrhash,
			    },
			    deps => \@sch_2form_deps,
		  }];

my $sch_3form  = [hash => {set=>1, 
			   keys => {
			       defs => "hash", # XXX of schema...
			       type => $sch_type, # XXX doesn't support subschema/nonbuiltin schemas
			       attr_hashes => [array => {
				   set => 1,
				   minlen => 1,
				   elem_regex=>{ 
				       '^0$' => $sch_attrhash0,
				       '[1-9]' => $sch_attrhash,
				   }
				   }}];

			    },
			    deps => \@sch_3form_deps,
		  }];

my $sch_schema = [either => {set=>1, of=>[qw/str array hash/], 
			     deps=>[
				[str => $sch_1form],
				[array => $sch_2form],
				[hash => $sch_3form],
				 ]}];

our $DS_Schema = $sch_schema;

#use YAML;
#print Dump $sch_schema;

1;
