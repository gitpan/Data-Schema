package Data::Schema;
our $VERSION = '0.136';


# ABSTRACT: (DEPRECATED) Validate nested data structures with nested structure


use Moose;
use Data::Schema::Config;
use Data::ModeMerge;
use Data::Schema::Type::Schema;
use Digest::MD5 qw/md5_hex/;
use Storable qw/freeze/;
#use Data::Dumper; # debugging

# for loading plugins/types on startup. see import()
my %Default_Plugins = (); # package name => object
my %Default_Types   = (
    # XXX aliases should not create different handler object
    str      => 'Str',
    string   => 'Str',
    cistr    => 'CIStr',
    cistring => 'CIStr',
    bool     => 'Bool',
    boolean  => 'Bool',
    hash     => 'Hash',
    array    => 'Array',
    object   => 'Object',
    obj      => 'Object',
    int      => 'Int',
    integer  => 'Int',
    float    => 'Float',
    either   => 'Either',
    or       => 'Either',
    any      => 'Either',
    all      => 'All',
    and      => 'All',

    typename => 'TypeName',
);
for (keys %Default_Types) { $Default_Types{$_} = "Data::Schema::Type::" . $Default_Types{$_} }

my %Package_Default_Types; # importing package => ...
my %Package_Default_Plugins; # importing package => ...
my $Current_Call_Pkg;


sub ds_validate {
    my ($data, $schema) = @_;
    my $ds = __PACKAGE__->new(schema => $schema);
    $ds->validate($data);
}

our $Merger = new Data::ModeMerge;
$Merger->config->recurse_array(1);



has plugins => (is => 'rw');
has type_handlers => (is => 'rw');

# we keep this hash for lexical visibility. although the sub might
# already be defined, but at times should not be visible to the
# schema.
has compiled_subnames => (is => 'rw');


has config => (is => 'rw');

has validation_state_stack => (is => 'rw');

# BEGIN validation state
has schema => (is => 'rw');
# has data_copy?
has too_many_errors => (is => 'rw');
has too_many_warnings => (is => 'rw');
has errors => (is => 'rw');
has warnings => (is => 'rw');
has data_pos => (is => 'rw');
has schema_pos => (is => 'rw');
has stash => (is => 'rw'); # for storing stuffs during validation
# END validation state

has logs => (is => 'rw'); # for debugging

has compilation_state_stack => (is => 'rw');

# BEGIN compilation state
# -- stash

# -- same as stash, but won't be reset during inner calls to _emit_perl
has outer_stash => (is => 'rw');
# END compilation state



sub BUILD {
    #print "DEBUG: Creating new DS object\n";
    my ($self, $args) = @_;

    # config
    if ($self->config) {
        # some sanity checks
        my $is_hashref = ref($self->config) eq 'HASH';
        die "config must be a hashref or a Data::Schema::Config" unless
            $is_hashref || UNIVERSAL::isa($self->config, "Data::Schema::Config");
        $self->config(Data::Schema::Config->new(%{ $self->config })) if $is_hashref;
        die "config->schema_search_path must be an arrayref" unless ref($self->config->schema_search_path) eq 'ARRAY';
    } else {
        $self->config(Data::Schema::Config->new);
    }

    # add default type handlers
    if ($args->{type_handlers}) {
        # some sanity checks
        die "type_handlers must be a hashref" unless ref($args->{type_handlers}) eq 'HASH';
    } else {
        $self->type_handlers({});
	my $deftypes = $Current_Call_Pkg && $Package_Default_Types{$Current_Call_Pkg} ? $Package_Default_Types{$Current_Call_Pkg} : \%Default_Types;
        $self->register_type($_, $deftypes->{$_}) for keys %$deftypes;
    }

    # add default plugins
    if ($self->plugins) {
        # some sanity checks
        die "plugins must be an arrayref" unless ref($self->plugins) eq 'ARRAY';
    } else {
        $self->plugins([]);
	my $defpl = $Current_Call_Pkg && $Package_Default_Plugins{$Current_Call_Pkg} ? $Package_Default_Plugins{$Current_Call_Pkg} : \%Default_Plugins;
        #print Dumper $defpl;
        $self->register_plugin($_) for keys %$defpl;
    }

    $self->validation_state_stack([])  unless $self->validation_state_stack;
    $self->compilation_state_stack([]) unless $self->compilation_state_stack;
    $self->compiled_subnames({})       unless $self->compiled_subnames;
};


sub merge_attr_hashes {
    my ($self, $attr_hashes) = @_;
    my @merged;
    #my $did_merging;
    my $res = {error=>''};

    my $i = -1;
    while (++$i < @$attr_hashes) {
        if (!$i) { push @merged, $attr_hashes->[$i]; next }
        my $has_merge_prefix = grep {/^[*+.!^-]/} keys %{ $attr_hashes->[$i] };
        if (!$has_merge_prefix) { push @merged, $attr_hashes->[$i]; next }
        my $mres = $Merger->merge($merged[-1], $attr_hashes->[$i]);
        #$did_merging++;
        #print "DEBUG: prefix_merge $i (".Data::Schema::Type::Base::_dump({}, $merged[-1]).", ".
        #    Data::Schema::Type::Base::_dump({}, $attr_hashes->[$i])." = ".($mres->{success} ? Data::Schema::Type::Base::_dump({}, $mres->{result}) : "FAIL")."\n";
        if (!$mres->{success}) {
            $res->{error} = $mres->{error};
            last;
        }
        $merged[-1] = $mres->{result};
    }
    $res->{result} = \@merged unless $res->{error};
    $res->{success} = !$res->{error};

    #print "DEBUG: merge_attr_hashes($self, ".Data::Schema::Type::Base::_dump({}, $attr_hashes).
    #    ") = ".($res->{success} ? Data::Schema::Type::Base::_dump({}, $res->{result}) : "FAIL")."\n";
    $res;
}


sub init_validation_state {
    my ($self) = @_;
    $self->schema(undef);
    $self->errors([]);
    $self->warnings([]);
    $self->too_many_errors(0);
    $self->too_many_warnings(0);
    $self->data_pos([]);
    $self->schema_pos([]);
    $self->stash({});
}


sub save_validation_state {
    my ($self) = @_;
    my $state = {
        schema => $self->schema,
        errors => $self->errors,
        warnings => $self->warnings,
        too_many_errors => $self->too_many_errors,
        too_many_warnings => $self->too_many_warnings,
        data_pos => $self->data_pos,
        schema_pos => $self->schema_pos,
        stash => $self->stash,
    };
    push @{ $self->validation_state_stack }, $state;
}


sub restore_validation_state {
    my ($self) = @_;
    my $state = pop @{ $self->validation_state_stack };
    die "Can't restore validation state, stack is empty!" unless $state;
    $self->schema($state->{schema});
    $self->errors($state->{errors});
    $self->warnings($state->{warnings});
    $self->too_many_errors($state->{too_many_errors});
    $self->too_many_warnings($state->{too_many_warnings});
    $self->data_pos($state->{data_pos});
    $self->schema_pos($state->{schema_pos});
    $self->stash($state->{stash});
}


sub init_compilation_state {
    my ($self, $inner) = @_;
    $self->stash({});
    $self->schema_pos([]) unless $self->schema_pos;
    $self->outer_stash({compiling=>1}) unless $inner;
}


sub save_compilation_state {
    my ($self) = @_;
    my $state = {
        stash => $self->stash,
    };
    push @{ $self->compilation_state_stack }, $state;
}


sub restore_compilation_state {
    my ($self) = @_;
    my $state = pop @{ $self->compilation_state_stack };
    die "Can't restore validation state, stack is empty!" unless $state;
    $self->stash($state->{stash});
}

sub emitpl_my {
    my ($self, @varnames) = @_;
    join("", map { !$self->stash->{"C_var_$_"}++ ? "my $_;\n" : "" } @varnames);
}

sub emitpl_require {
    my ($self, @modnames) = @_;
    join("", map { !$self->outer_stash->{"C_req_$_"}++ ? "require $_;\n" : "" } @modnames);
}


sub data_error {
    my ($self, $message) = @_;
    return if $self->too_many_errors;
    do { $self->too_many_errors(1); $self->debug("Too many errors", 3); return } if
	defined($self->config->max_errors) && $self->config->max_errors > 0 &&
	@{ $self->errors } >= $self->config->max_errors;
    push @{ $self->errors }, [[@{$self->data_pos}], [@{$self->schema_pos}], $message];
}

sub emitpl_data_error {
    my ($self, $msg, $is_literal) = @_;
    my $perl;

    my $lit;
    if ($is_literal) {
        $lit = $msg;
    } else {
        $msg =~ s/(['\\])/\\$1/g;
        $lit = "'$msg'";
    }
    $perl = 'push @errors, [[@$datapos],[@$schemapos],'.$lit.']; last L1 if @errors >= '.$self->config->max_errors.";";
    if (defined($self->config->max_errors) && $self->config->max_errors > 0) {
	$perl = 'if (@errors < '.$self->config->max_errors.') { '.$perl.' }';
    }
    $perl;
}


sub data_warn {
    my ($self, $message) = @_;
    return if $self->too_many_warnings;
    do { $self->too_many_warnings(1); return } if
	defined($self->config->max_warnings) && $self->config->max_warnings > 0 &&
	@{ $self->warnings } >= $self->config->max_warnings;
    push @{ $self->warnings }, [[@{$self->data_pos}], [@{$self->schema_pos}], $message];
}

sub emitpl_data_warn {
    my ($self, $msg, $is_literal) = @_;
    my $perl;

    my $lit;
    if ($is_literal) {
        $lit = $msg;
    } else {
        $msg =~ s/(['\\])/\\$1/g;
        $lit = "'$msg'";
    }
    $perl = 'push @warnings, [[@$datapos],[@$schemapos],'.$lit.']; ';
    if (defined($self->config->max_warnings) && $self->config->max_warnings > 0) {
    	$perl = 'if (@warnings < '.$self->config->max_warnings.') { '.$perl.'} ';
    }
    $perl;
}


sub debug {
    my ($self, $message, $level) = @_;
    $level //= 1; # XXX should've been: 1=FATAL, 2=ERROR, 3=WARN, 4=INFO, 5=DEBUG as usual
    return unless $level <= $self->config->debug;
    $message = $message->() if ref($message) eq 'CODE';
    push @{ $self->logs }, [[@{$self->data_pos}], [@{$self->schema_pos}], $message];
}

sub emitpl_push_errwarn {
    my ($self, $errorsvarname, $warningsvarname) = @_;
    $errorsvarname //= 'suberrors';
    $warningsvarname //= 'subwarnings';
    my $perl1 = 'push @warnings, @$'.$warningsvarname.'; ';
    if (defined($self->config->max_warnings) && $self->config->max_warnings > 0) {
    	$perl1 = 'if (@warnings < '.$self->config->max_warnings.') { '.$perl1.'} ';
    }
    my $perl2 .= 'push @errors, @$'.$errorsvarname.'; last L1 if @errors >= '.$self->config->max_errors."; ";
    if (defined($self->config->max_errors) && $self->config->max_errors > 0) {
        $perl2 = 'if (@errors < '.$self->config->max_errors.') { '.$perl2.'} ';
    }
    $perl1 . $perl2;
}


sub schema_error {
    my ($self, $message) = @_;
    die "Schema error: $message";
}

sub _pos_as_str {
    my ($self, $pos_elems) = @_;
    my $res = join "/", @$pos_elems;
    $res =~ s/\s+/_/sg;
    $res;
}


sub check_type_name {
    my ($self, $name) = @_;
    $name =~ /\A[a-z_][a-z0-9_]{0,63}\z/;
    # XXX synchronize with DST::TypeName
}

sub _load_type_handler {
    my ($self, $name) = @_;
    my $obj_or_class = $self->type_handlers->{$name};
    die "BUG: unknown type: $name" unless $obj_or_class;
    return $obj_or_class if ref($obj_or_class);
    eval "require $obj_or_class";
    die "Can't load class $obj_or_class: $@" if $@;
    my $obj = $obj_or_class->new();
    $obj->validator($self);
    $self->type_handlers->{$name} = $obj;
    $obj;
}


sub register_type {
    my ($self, $name, $obj_or_class) = @_;

    $self->check_type_name($name) or die "Invalid type name syntax: $name";

    if (exists $self->type_handlers->{$name}) {
        die "Type already registered: $name";
    }

    $self->type_handlers->{$name} = $obj_or_class;

    if (ref($obj_or_class)) {
        $obj_or_class->validator($self);
    } elsif (!$self->config->defer_loading) {
        $self->_load_type_handler($name);
    }
}


sub register_plugin {
    my ($self, $obj_or_class) = @_;

    my $obj;
    if (ref($obj_or_class)) {
        $obj = $obj_or_class;
    } else {
        eval "use $obj_or_class";
        die "Can't load class $obj_or_class: $@" if $@;
        $obj = $obj_or_class->new();
    }
    $obj->validator($self);
    push @{ $self->plugins }, $obj;
}


sub call_handler {
    my ($self, $name, @args) = @_;
    $name = "handle_$name" unless $name =~ /^handle_/;
    for my $p (@{ $self->plugins }) {
        if ($p->can($name)) {
            #print "DEBUG: calling plugin $p, handler $name ...\n";
	    my $res = $p->$name(@args);
            #print "DEBUG: res = $res ...\n";
            return $res if $res != -1;
        }
    }
    -1;
}


sub get_type_handler {
    my ($self, $name) = @_;
    my $th;
    #print "DEBUG: Getting type handler for type $name ...\n";
    #print "DEBUG: Current type handlers: ", Data::Dumper->new([$self->type_handlers])->Indent(1)->Dump;
    if (!($th = $self->type_handlers->{$name})) {
        # let's give plugin a chance to do something about it and then try again
        if ($self->call_handler("unknown_type", $name) > 0) {
            $th = $self->type_handlers->{$name};
        }
    } else {
        unless (ref($th)) {
            $th = $self->_load_type_handler($name);
        }
    }
    #print "DEBUG: Type handler got: ".Dumper($th)."\n";
    $th;
}


sub normalize_schema {
    my ($self, $schema) = @_;

    if (!defined($schema)) {

        return "schema is missing";

    } elsif (!ref($schema)) {

        return { type=>$schema, attr_hashes=>[], def=>undef };

    } elsif (ref($schema) eq 'ARRAY') {

        my $type = $schema->[0];
        if (!defined($type)) {
            return "array form needs at least 1 element for type";
        }
        my @attr_hashes;
        for (1..@$schema-1) {
            if (ref($schema->[$_]) ne 'HASH') {
                return "array form element [$_] (attrhash) must be a hashref";
            }
            push @attr_hashes, $schema->[$_];
        }
        return { type=>$type, attr_hashes=>\@attr_hashes, def=>undef };

    } elsif (ref($schema) eq 'HASH') {

        my $type = $schema->{type};
        if (!defined($type)) {
            return "hash form must have 'type' key";
        }
        my @attr_hashes;
        my $a = $schema->{attrs};
        if (defined($a)) {
            if (ref($a) ne 'HASH') {
                return "hash form 'attrs' key must be a hashref";
            }
            push @attr_hashes, $a;
        }
        $a = $schema->{attr_hashes};
        if (defined($a)) {
            if (ref($a) ne 'ARRAY') {
                return "hash form 'attr_hashes' key must be an arrayref";
            }
            for (0..@$a-1) {
                if (ref($a->[$_]) ne 'HASH') {
                    return "hash form 'attr_hashes'[$_] must be a hashref";
                }
                push @attr_hashes, $a->[$_];
            }
        }
        my $def = {};
        $a = $schema->{def};
        if (defined($a)) {
            if (ref($a) ne 'HASH') {
                return "hash form 'def' key must be a hashref";
            }
        }
        $def = $a;
        for (keys %$schema) {
            return "hash form has unknown key `$_'" unless /^(type|attrs|attr_hashes|def)$/;
        }
        return { type=>$type, attr_hashes=>\@attr_hashes, def=>$def };

    }

    return "schema must be a str, arrayref, or hashref";
}


sub register_schema_as_type {
    my ($self, $nschema, $name, $path) = @_;
    $path ||= "";
    my $res = {};

    while (1) {
        if ($self->type_handlers->{$name}) {
            $res->{error} = "type `$name' already registered (path `$path')";
            last;
        }
        if (ref($nschema) ne 'HASH') {
            $res->{error} = "schema must be in 3rd form (hash): (path `$path')";
            last;
        }
        if ($nschema->{def}) {
            for (keys %{ $nschema->{def} }) {
                my $r = $self->register_schema_as_type($nschema->{def}{$_}, $_, "$path/$_");
                if (!$r->{success}) {
                    $res->{error} = $r->{error};
                    last;
                }
            }
        }
        my $th = Data::Schema::Type::Schema->new(nschema=>$nschema, name=>$name);
        $self->register_type($name => $th);
        last;
    }
    $res->{success} = !$res->{error};
    $res;
}


sub validate {
    my ($self, $data, $schema) = @_;
    my $saved_schema = $self->schema;
    $schema ||= $self->schema;

    $self->init_validation_state();
    $self->init_compilation_state() if $self->config->compile;
    $self->logs([]);
    $self->_validate($data, $schema);
    $self->schema($saved_schema);

    {success  => !@{$self->errors},
     errors   => [$self->errors_as_array],
     warnings => [$self->warnings_as_array],
     logs     => [$self->logs_as_array],
    };
}


sub errors_as_array {
    my ($self) = @_;
    map { sprintf "%s (data\@%s schema\@%s)", $_->[2], $self->_pos_as_str($_->[0]), $self->_pos_as_str($_->[1]) } @{ $self->errors };
}


sub warnings_as_array {
    my ($self) = @_;
    map { sprintf "%s (data\@%s schema\@%s)", $_->[2], $self->_pos_as_str($_->[0]), $self->_pos_as_str($_->[1]) } @{ $self->warnings };
}


sub logs_as_array {
    my ($self) = @_;
    map { sprintf "%s (data\@%s schema\@%s)", $_->[2], $self->_pos_as_str($_->[0]), $self->_pos_as_str($_->[1]) } @{ $self->logs };
}

sub _schema2csubname {
    my ($self, $schema) = @_;

    # deal with perl hash randomization
    local $Storable::canonical = 1;

    # avoid warning from Storable when trying to freeze coderef
    local $self->config->{gettext_function} =
	($self->config->{gettext_function} // "")."";

    my $n1 = defined($schema) ? (ref($schema) ? md5_hex(freeze($schema)) : $schema) : "";
    my $n2 = md5_hex(freeze($self->config));
    "__cs_${n1}_$n2";
}


sub emit_perl {
    my ($self, $schema, $inner) = @_;
    $self->init_compilation_state($inner);
    $self->_emit_perl(undef, $schema);
}

sub _emit_perl {
    _validate_or_emit_perl(@_, 'EMIT_PERL');
}

# the difference between validate() and _validate(): _validate() is not for the
# end-user, it doesn't initialize validation state and so can be used in the
# middle of another validation (e.g. for validating schema types). _validate()
# also doesn't format and returns the list of errors, you need to get them
# yourself from the validator.

sub _validate {
    my ($self, $data, $schema) = @_;
    _validate_or_emit_perl(@_, 'VALIDATE');
}

sub _validate_or_emit_perl {
    my ($self, $data, $schema, $action) = @_;

    die "Schema must be specified" unless defined($schema);

    my $compile = $self->config->compile;
    my $csubname = $self->_schema2csubname($schema);
    if ($compile && $action eq 'VALIDATE' && $self->compiled_subnames->{$csubname}) {
	#print "HIT!\n";
	goto LV1;
    }

    # since schema may define types inside it, we save the original types list
    # so we can register new types and then restore back to original state
    # later.
    my $orig_type_handlers;
    my $orig_compiled_subnames;

    {
        my $s = $self->normalize_schema($schema);
        if (!ref($s)) {
            $self->schema_error($s);
            last;
        }

        if ($s->{def}) {
	    #print "DEBUG: Saving type handlers\n";
            $orig_type_handlers = { %{$self->type_handlers} };
            $orig_compiled_subnames = { %{$self->compiled_subnames} };
            push @{ $self->schema_pos }, 'def', '';
            my $has_err;
            for (keys %{ $s->{def} }) {
                $self->schema_pos->[-1] = $_;
                my $subs = $self->normalize_schema($s->{def}{$_});
                if (!ref($subs)) {
                    $has_err++;
                    $self->data_error("normalize schema type error: $s");
                    last;
                }
                my $res = $self->register_schema_as_type($subs, $_);
                if (!$res->{success}) {
                    $has_err++;
                    $self->data_error("register schema type error: $res->{error}");
                    last;
                }
            }
            pop @{ $self->schema_pos };
            pop @{ $self->schema_pos };
            last if $has_err;
        }

        my $th = $self->get_type_handler($s->{type});
        if (!$th) {
            $self->schema_error("unknown type `$s->{type}'");
            last;
        }
        if ($compile || $action eq 'EMIT_PERL') {
	    $self->outer_stash->{"C_def_$csubname"}++;
            my $code = $th->emit_perl($s->{attr_hashes}, $csubname);
            return $code if $action eq 'EMIT_PERL';
            if (!$code) {
                $self->schema_error("no Perl code generated");
                last;
            }
	    unless ($Data::Schema::__compiled::{$csubname}) {
		eval "package Data::Schema::__compiled; $code; package Data::Schema;";
		my $eval_error = $@;
		if ($eval_error) {
		    my $i=1; my @c; for (split /\n/, $code) { push @c, sprintf "%4d|%s\n", $i++, $_ } $code = join "", @c;
		    print STDERR $code;
		    print STDERR $eval_error;
		    die "Can't compile code: $eval_error";
		}
	    }
	    #print "DEBUG: Compiled $csubname\n";
	    $self->compiled_subnames->{$csubname} = 1;
        } else {
            $th->handle_type($data, $s->{attr_hashes});
        }
    }

    if ($orig_type_handlers) {
	#print "DEBUG: Restoring original type handlers\n";
	$self->type_handlers($orig_type_handlers);
	$self->compiled_subnames($orig_compiled_subnames);
    }

  LV1:
    # execute compiled code
    if ($compile) {
        no strict 'refs';
	my ($errors, $warnings) = "Data::Schema::__compiled::$csubname"->($data);
	push @{ $self->errors   }, @$errors;
	push @{ $self->warnings }, @$warnings;
    }
}


sub compile {
    my ($self, $schema) = @_;
    my $csubname = $self->_schema2csubname($schema);
    unless ($Data::Schema::__compiled::{$csubname}) {
	$self->save_compilation_state;
	my $code = $self->emit_perl($schema);
	$self->restore_compilation_state;
	die "Can't generate Perl code for schema" unless $code;
	eval "package Data::Schema::__compiled; $code; package Data::Schema;";
	my $eval_error = $@;
	if ($eval_error) {
	    my $i=1; my @c; for (split /\n/, $code) { push @c, sprintf "%4d|%s\n", $i++, $_ } $code = join "", @c;
	    print STDERR $code;
	    print STDERR $eval_error;
	    die "Can't compile code: $eval_error";
	}
    }
    my $cfullsubname = "Data::Schema::__compiled::$csubname";
    (\&$cfullsubname, $csubname);
}

sub emitpls_sub {
    my ($self, $schema) = @_;

    my $csubname = $self->_schema2csubname($schema);
    #print "DEBUG: emitting $csubname\n";
    my $perl = '';

    if ($Data::Schema::__compiled::{$csubname} ||
	$self->outer_stash->{"C_def_$csubname"}++) {
	#print "DEBUG: skipped emitting $csubname (already done)\n";
    } else {
	#print "DEBUG: marking $csubname in outer stash\n";
	$self->outer_stash->{"C_def_$csubname"}++;
	$self->save_compilation_state;
	$perl = $self->emit_perl($schema, 1);
	$self->restore_compilation_state;
	die "Can't generate Perl code for schema" unless $perl;
    }
    ($perl, $csubname);
}

sub import {
    my $pkg = shift;
    $Current_Call_Pkg = caller(0);

    no strict 'refs';

    # default export
    my @export = qw(ds_validate);
    *{$Current_Call_Pkg."::$_"} = \&{$pkg."::$_"} for @export;

    return if $Package_Default_Types{$Current_Call_Pkg};
    my $dt = { %Default_Types };
    my $dp = { %Default_Plugins };
    for (@_) {
        my $e = $_;
	if (grep {$e eq $_} @export) {
	} elsif ($e =~ /^Plugin::/) {
            $e = "Data::Schema::" . $e;
	    unless (grep {$_ eq $e} keys %$dp) {
		eval "require $e"; die $@ if $@;
		$dp->{$e} = $e->new();
	    }
	} elsif ($e =~ /^Type::/) {
	    $e = "Data::Schema::" . $e;
	    eval "require $e"; die $@ if $@;
	    my $th = $e->new();
	    my $names = ${$e."::DS_TYPE"};
	    die "$e doesn't have \$DS_TYPE" unless $names;
	    $names = [$names] unless ref($names) eq 'ARRAY';
            for (@$names) {
		if (!check_type_name(undef, $_)) {
		    die "$e tries to define invalid type name: `$_`";
		} elsif (exists $dt->{$_}) {
		    die "$e tries to redefine existing type '$_' (handler: $dt->{$_})";
		}
		$dt->{$_} = $e;
	    }
	} elsif ($e =~ /^Schema::/) {
	    $e = "Data::Schema::" . $e;
	    eval "require $e"; die $@ if $@;
	    my $schemas = ${$e."::DS_SCHEMAS"};
	    die "$e doesn't have \$DS_SCHEMAS" unless $schemas;
            for (keys %$schemas) {
		if (!check_type_name(undef, $_)) {
		    die "$e tries to define invalid type name: `$_`";
		} elsif (exists $dt->{$_}) {
		    die "$e tries to redefine existing type '$_' (handler: $dt->{$_})";
		}
	        my $nschema = normalize_schema(undef, $schemas->{$_});
		if (ref($nschema) ne 'HASH') {
		    die "Can't normalize schema in $e: $nschema";
		}
		require Data::Schema::Type::Schema;
		$dt->{$_} = Data::Schema::Type::Schema->new(nschema=>$nschema, name=>$_);
	    }
	} else {
	    die "Can't export $_! Can only export: ".join(@export, '/^{Plugin,Type,Schema}::.*/');
	}
    }
    $Package_Default_Types{$Current_Call_Pkg} = $dt;
    $Package_Default_Plugins{$Current_Call_Pkg} = $dp;
    #print Dumper(\%Package_Default_Plugins);
}


__PACKAGE__->meta->make_immutable;
no Moose;
1;

__END__
=pod

=head1 NAME

Data::Schema - (DEPRECATED) Validate nested data structures with nested structure

=head1 VERSION

version 0.136

=head1 SYNOPSIS

    # OO interface
    use Data::Schema;
    my $ds = Data::Schema->new();
    my $schema = [array => {min_len=>2, max_len=>4}];
    my $data = [1, 2, 3];
    my $res = $ds->validate($data, $schema);
    print "valid!" if $res->{success}; # prints 'valid!'

    # procedural interface
    use Data::Schema;
    my $sch = ["hash",
               {keys =>
                    {name => "str",
                     age  => ["int", {required=>1, min=>18}]
                    }
                }
              ];
    my $r;
    $r = ds_validate({name=>"Lucy", age=>18}, $sch); # success
    $r = ds_validate({name=>"Lucy"         }, $sch); # fail: missing age
    $r = ds_validate({name=>"Lucy", age=>16}, $sch); # fail: underage

    # some schema examples

    # -- array
    "array"

    # -- array of ints
    [array => {of=>"int"}]

    # -- array of positive, even ints
    [array => {of=>[int => {min=>0, divisible_by=>2}]}]

    # -- 3x3x3 "multi-dim" arrays
    [array => {len=>3, of=>
        [array => {len=>3, of=>
            [array => {len=>3}]}]}]

    # -- HTTP headers, each header can be a string or array of strings
    [hash => {
        required => 1,
        keys_match => '^\w+(-w+)*$',
        values_of => [either => {of=>[
            "str",
            [array=>{of=>"str", minlen=>1}],
        ]}],
    }]

    # -- records (demonstrates subschema and attribute merging). Note:
    # I am not sexist or anything, just that for the love of g*d I
    # can't think of a better example atm. it's late...
    {def => {
        person => [hash => {
            keys => {
                name       => "str",
                race       => "str",
                age        => [int => {min=>0, max=>100}],
            },
        }],

        # women are like people, but they have additional keys
        # 'husband' and 'cup_size' (additive) and different age
        # restriction (replace).

        woman => [person => {
            '*keys' => {
                husband    => "str",
                cup_size   => [str => {one_of=>[qw/AA A B C D DD/]}],
                '*age'     => [int => {min=>0, max=>120}],
            },
        }],

        # girls are like women, but they do not have husbands yet
        # (remove keys)

        girl => [woman => {
            '*keys' => {
                '!husband' => undef,
            }
        }],

        girls  => [array => {of=>"girl"}],
    },
    type => "girls",
    };

=head1 DESCRIPTION

B<NOTE: THIS MODULE IS DEPRECATED AND WILL NOT BE DEVELOPED FURTHER. PLEASE
SEE Data::Sah INSTEAD.>

Data::Schema (DS) is a schema system for data validation. It lets you
write schemas as data structures, ranging from very simple (a scalar)
to fairly complex (nested hashes/arrays with various criteria).

Writing schemas as data structures themselves has several advantages. First, it
is more portable across languages (e.g. using YAML to share schemas between
Perl, Python, PHP, Ruby). Second, you can validate the schema using the schema
system itself. Third, it is easy to generate code, help message (e.g. so-called
"usage" for function/command line script), etc. from the schema.

Potential application of DS: validating configuration, function
parameters, command line arguments, etc.

To get started, see L<Data::Schema::Manual::Tutorial>.

=head1 IMPORTING

When importing this module, you can pass a list of module names.

 use Data::Schema qw(Plugin::Foo Type::Bar Schema::Baz ...);
 my $ds = Data::Schema->new; # foo, bar, baz will be loaded by default

This is a shortcut to the more verbose form:

 use Data::Schema;
 my $ds = Data::Schema->new;

 $ds->register_plugin('Data::Schema::Plugin::Foo');

 $ds->register_type('bar', 'Data::Schema::Type::Bar');

 use Data::Schema::Schema::Baz;
 $ds->register_schema_as_type($_, $Data::Schema::Schema::Baz::DS_SCHEMAS->{$_})
    for keys %$Data::Schema::Schema::Baz::DS_SCHEMAS;

=head1 FUNCTIONS

=head2 ds_validate($data, $schema)

Non-OO wrapper for validate(). Exported by default. See C<validate()> method.

=head1 ATTRIBUTES

=head2 config

Configuration object. See L<Data::Schema::Config>.

=head1 METHODS

=head2 merge_attr_hashes($attr_hashes)

Merge several attribute hashes if there are hashes that can be merged (i.e.
contains merge prefix in its keys). Used by DST::Base and DST::Schema. As DS
user, normally you wouldn't need this.

=head2 init_validation_state()

Initialize validation state. Used internally by validate(). As DS user, normally
you wouldn't need this.

=head2 save_validation_state()

Save validation state (position in data, position in schema, number of errors,
etc) into a stack, so that you can start using the validator to validate a new
data with a new schema, even in the middle of validating another data/schema.
Used internally by validate() and DST::Schema. As DS user, normally you wouldn't
need this.

See also: B<restore_validation_state()>.

=head2 restore_validation_state()

Restore the last validation state from the stack. Used internally by
validate() and DST::Schema. As DS user, normally you wouldn't need
this.

See also: B<save_validation_state()>.

=head2 init_compilation_state()

Initialize compilation state. Used internally by emit_perl(). As DS
user, normally you wouldn't need this.

=head2 save_compilation_state()

Save compilation state. Used internally by emit_perl() and
DST::Schema. As DS user, normally you wouldn't need this.

See also: B<restore_compilation_state()>.

=head2 restore_compilation_state()

Restore the last compilation state from the stack. Used internally by
emit_perl() and DST::Schema. As DS user, normally you wouldn't need
this.

See also: B<save_compilation_state()>.

=head2 data_error($message)

Add a data error when in validation process. Will not add if there are
already too many errors (C<too_many_errors> attribute is true). Used
by type handlers. As DS user, normally you wouldn't need this.

=head2 data_warn($message)

Add a data warning when in validation process. Will not add if there
are already too many warnings (C<too_many_warnings> attribute is
true). Used by type handlers. As DS user, normally you wouldn't need
this.

=head2 debug($message[, $level])

Log debug messages. Used by type handlers when validating. As DS user,
normally you wouldn't need this.

=head2 schema_error($message)

Method to call when encountering schema error during
validation/compilation. Used by type handlers. As DS user, normally
you wouldn't need this.

=head2 check_type_name($name)

Checks whether C<$name> is a valid type name. Returns true if valid,
false if invalid. By default it requires that type name starts with a
lowercase letter and contains only lowercase letters, numbers, and
underscores. Maximum length is 64.

You can override this method if you want stricter/looser type name
criteria.

=head2 register_type($name, $class|$obj)

Register a new type, along with a class name (C<$class>) or the actual object
(C<$obj>) to handle the type. If C<$class> is given, the class will be require'd
and instantiated to become object later when needed via get_type_handler.

Any object can become a type handler, as long as it has:

=over

=item *

a C<validator()> rw property to store/set validator object;

=item *

C<handle_type()> method to handle type checking;

=item *

zero or more C<handle_attr_*()> methods to handle attribute checking.

=back

See L<Data::Schema::Manual::TypeHandler> for more details on writing a type
handler.

=head2 register_plugin($class|$obj)

Register a new plugin. Accept a plugin object or class. If C<$class> is given,
the class will be require'd (if not already require'd) and instantiated to
become object.

Any object can become a plugin, you don't need to subclass from anything, as
long as it has:

=over 4

=item *

a C<validator()> rw property to store/set validator object;

=item *

zero or more C<handle_*()> methods to handle some events/hooks.

=back

See L<Data::Schema::Manual::Plugin> for more details on writing a plugin.

=head2 call_handler($name, [@args])

Try handle_*() method from each registered plugin until one returns 0 or 1. If
a plugin return -1 (decline) then we continue to the next plugin. Returns the
status of the last plugin. Returns -1 if there's no handler to invoke.

=head2 get_type_handler($name)

Try to get type handler for a certain type. If type handler is not an object (a
class name), instantiate it first. If type is not found, invoke
handle_unknown_type() in plugins to give plugins a chance to load the type. If
type is still not found, return undef.

=head2 normalize_schema($schema)

Normalize a schema into the third form (hash form) ({type=>...,
attr_hashes=>..., def=>...) as well as do some sanity checks on it. Returns an
error message string if fails.

=head2 register_schema_as_type($schema, $name)

Register schema as new type. $schema is a normalized schema. Return {success=>(0
or 1), error=>...}. Fails if type with name B<$name> is already defined, or if
$schema cannot be parsed. Might actually register more than one type actually,
if the schema contains other types in it (hash form of schema can define types).

=head2 validate($data[, $schema])

Validate a data structure. $schema must be given unless you already give the
schema via the B<schema> attribute.

Returns {success=>0 or 1, errors=>[...], warnings=>[...]}. The
'success' key will be set to 1 if the data validates, otherwise
'errors' will be filled with the details.

=head2 errors_as_array

Return formatted errors in an array of strings.

=head2 warnings_as_array

Return formatted warnings in an array of strings.

=head2 logs_as_array

Return formatted logs in an array of strings.

=head2 emit_perl([$schema])

Return Perl code equivalent to schema C<$schema>.

If you want to get the compiled code (as a coderef) directly, use
C<compile>.

=head2 compile($schema)

Compile the schema into Perl code and return a 2-element list:
($coderef, $subname). $coderef is the resulting subroutine and
$subname is the subroutine name in the compilation namespace
(Data::Schema::__compiled).

If the same schema is already compiled, the existing compiled
subroutine is returned instead.

Dies if code can't be generated, or an error occured when compiling
the code.

If you just want to get the Perl code in a string, use C<emit_perl>.

=head1 COMPARISON WITH OTHER DATA VALIDATION MODULES

There are already a lot of data validation modules on CPAN. However, most of
them do not validate nested data structures. Many seem to focus only on "form"
(which is usually presented as shallow hash in Perl).

And of the rest which do nested data validation, either I am not really fond of
the syntax, or the validator/schema system is not simple/flexible/etc enough for
my taste. For example, other data validation modules might require you to always
write:

 { type => "int" }

even when all you want is just validating an int with no other extra
requirements. With DS you can just write:

 "int"

Another design consideration for DS is, I want to maximize reusability of my
schemas. And thus DS allows you to define schemas in terms of other schemas.
External schemas can be "require"-d from Perl variables or loaded from YAML
files. Of course, you can also extend with Perl as usual (e.g. writing new
types and new attributes).

=head1 SEE ALSO

L<Data::Schema::Manual::Tutorial>

L<Data::Schema::Manual::Schema>

L<Data::Schema::Manual::TypeHandler>

L<Data::Schema::Manual::Plugin>

Some other data validation modules on CPAN: L<Data::FormValidator>, L<Data::Rx>,
L<Kwalify>.

L<Config::Tree> uses Data::Schema to check command-line options and
makes it easy to generate --help/usage information.

L<LUGS::Events::Parser> by Steven Schubiger is apparently one of the
first modules (outside my own of course) which use Data::Schema.

L<Data::Schema::Schema::> namespace is reserved for modules that
contain DS schemas. For example, L<Data::Schema::Schema::CPANMeta>
validates CPAN META.yml. L<Data::Schema::Schema::Schema> contains the
schema for DS schema itself.

=head1 BUGS

Please report any bugs or feature requests to C<bug-data-schema at
rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Data-Schema>.  I
will be notified, and then you'll automatically be notified of
progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Data::Schema

You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Data-Schema>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Data-Schema>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Data-Schema>

=item * Search CPAN

L<http://search.cpan.org/dist/Data-Schema/>

=back

=head1 ACKNOWLEDGEMENTS

=head1 AUTHOR

  Steven Haryanto <stevenharyanto@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2009 by Steven Haryanto.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

