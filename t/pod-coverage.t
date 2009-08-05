use strict;
use warnings;
use Test::More tests => 13;

# Ensure a recent version of Test::Pod::Coverage
my $min_tpc = 1.08;
eval "use Test::Pod::Coverage $min_tpc";
plan skip_all => "Test::Pod::Coverage $min_tpc required for testing POD coverage"
    if $@;

# Test::Pod::Coverage doesn't require a minimum Pod::Coverage version,
# but older versions don't recognize some common documentation styles
my $min_pc = 0.18;
eval "use Pod::Coverage $min_pc";
plan skip_all => "Pod::Coverage $min_pc required for testing POD coverage"
    if $@;

my $DS = "Data::Schema";
my $DST = "${DS}::Type";
my $DSP = "${DS}::Plugin";

pod_coverage_ok("${DS}", { also_private => [ qr/^(BUILD)$/ ], }, "${DS}");

# XXX DST::Base

for (qw(Array Bool Float Int Hash Schema Str Either All Object)) {
    pod_coverage_ok("${DST}::$_", { also_private => [ qr/^(handle_type|handle_pre_check_attrs|handle_attr_.*|cmp|type_in_english|BUILD)$/ ], }, "${DST}::$_");
}

# XXX DSP::LoadSchema::Base

for (qw(Hash YAMLFile)) {
    pod_coverage_ok("${DSP}::LoadSchema::$_", { also_private => [ qr/^(handle_unknown_type|BUILD)$/ ], }, "${DSP}::LoadSchema::$_");
}
