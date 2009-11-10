package Data::Schema::Config;

use Moose;

=head1 NAME

Data::Schema::Config - Data::Schema configuration

=head1 SYNOPSIS

    # getting configuration
    if ($validator->config->allow_extra_hash_keys) { ... }

    # setting configuration
    $validator->config->max_warnings(100);

=head1 DESCRIPTION

Configuration variables for Data::Schema.

=head1 ATTRIBUTES

=head2 max_errors => INT

Maximum number of errors before validation stops. Default is 10.

=cut

has max_errors => (is => 'rw', default => 10);

=head2 max_warnings => INT

Maximum number of warnings before warnings will not be added anymore. Default is
10.

=cut

has max_warnings => (is => 'rw', default => 10);

=head2 schema_search_path => ARRAYREF

A list of places to look for schemas. If you use DSP::LoadSchema::YAMLFile, this
will be a list of directories to search for YAML files. If you use
DSP::LoadSchema::Hash, this will be the hashes to search for schemas. This is
used if you use schema types (types based on schema).

See <Data::Schema::Type::Schema> for more details.

=cut

has schema_search_path => (is => 'rw', default => sub { ["."] });

=head2 gettext_function => CODEREF

If set to a coderef, then this will be used to get custom error message when
errmsg attribute suffix is used. For example, if schema is:

 [str => {regex=>'/^\w+$/', 'regex.errmsg'=>'alphanums_only'}]

then your function will be called with 'alphanums_only' as the argument.

Default is none.

=cut

has gettext_function => (is => 'rw');

=head2 defer_loading => BOOL

Default true. If set to true, try to load require/use as later as
possible (e.g.  loading type handler classes, etc) to improve startup
performance.

=cut

has defer_loading => (is => 'rw', default => 1);

=head2 allow_extra_hash_keys => BOOL

Default false. When hash has 'keys' type attribute, it automatically limits
allowed keys to only those specified in 'keys'. But if you set this config to
true, extra keys will still be allowed.

Example:

 # under allow_extra_hash_keys = 0 (the default)
 ds_validate({c=>1}, [hash => {keys=>{a=>"int", b=>"int"}}]); # failed, key c not allowed

 # under allow_extra_hash_keys = 1
 ds_validate({c=>1}, [hash => {keys=>{a=>"int", b=>"int"}}]); # ok
 # but
 ds_validate({c=>1}, [hash => {keys=>{a=>"int", b=>"int"},
                               allowed_keys=>[qw/a b/]}]); # still not allowed due to allowed_keys

=cut

has allow_extra_hash_keys => (is => 'rw', default => 0);

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
