package Data::Schema::Type::Base;
our $VERSION = '0.135';


# ABSTRACT: Base class for Data::Schema type handler


use Moose;
use Data::Dumper;
use Scalar::Util qw/tainted looks_like_number blessed/;

has 'validator' => (is => 'rw');
with 'Data::Schema::Type::Printable';

sub _dump {
    _perl(@_);
}

sub _emitpl_dump {
    _emitpl_perl(@_);
}

sub _emitpl_perl {
    my ($self, $var, $lit) = @_;
    "Data::Dumper->new([".($lit ? $var : $self->_dump($var))."]".")->Indent(0)->Terse(1)->Sortkeys(1)->Purity(0)->Dump()";
}

sub _perl {
    my ($self, $val) = @_;
    Data::Dumper->new([$val])->Indent(0)->Terse(1)->Sortkeys(1)->Purity(0)->Dump();
}

sub __make_attr_alias {
    my ($name, @aliases) = @_;
    for (@aliases) {
        eval 
            "package ".caller(0).";".
            "sub chkarg_attr_$_ { chkarg_attr_$name(\@_) } ".
            "sub handle_attr_$_ { handle_attr_$name(\@_) } ".
            "sub emitpl_attr_$_ { emitpl_attr_$name(\@_) } ";
        $@ and die "Can't make attr alias $_ -> $name: $@";
    }
}

sub chkarg_required {
    my ($self, $arg, $name) = @_;
    my $ds = $self->validator;
    unless (defined($arg)) {
        $ds->schema_error("$name: value required");
        return;
    }
    1;
}

sub chkarg_r_num {
    my ($self, $arg, $name) = @_;
    my $ds = $self->validator;
    return unless chkarg_required(@_);
    unless (looks_like_number($arg)) {
        $ds->schema_error("$name: must be a number");
        return;
    }
    1;
}

sub chkarg_r_int {
    my ($self, $arg, $name) = @_;
    my $ds = $self->validator;
    return unless chkarg_r_num(@_);
    unless ($arg == int($arg)) {
        $ds->schema_error("$name: must be an int");
        return;
    }
    1;
}

sub chkarg_r_str {
    my ($self, $arg, $name) = @_;
    my $ds = $self->validator;
    return unless chkarg_required(@_);
    unless (!ref($arg)) {
        $ds->schema_error("$name: must be a string");
        return;
    }
    1;
}

sub chkarg_bool {
    my ($self, $arg, $name) = @_;
    my $ds = $self->validator;
    return 1 unless defined($arg);
    unless (!ref($arg)) {
        $ds->schema_error("$name: must be a bool");
        return;
    }
    1;
}

sub chkarg_r_bool { chkarg_r_str(@_) }

sub chkarg_r_typename {
    my ($self, $arg, $name) = @_;
    my $ds = $self->validator;
    return unless chkarg_r_str(@_);
    if (!$ds->check_type_name($arg)) {
        $ds->schema_error("$name: invalid type name `$arg`");
        return;
    }
    1;
}

sub chkarg_r_regex {
    my ($self, $arg, $name) = @_;
    my $ds = $self->validator;
    return unless chkarg_required(@_);
    unless (!ref($arg) || ref($arg) eq 'Regexp') {
        $ds->schema_error("$name: regex must be string or Regexp object");
        return;
    }
    eval { qr/$arg/ };
    if ($@) {
        $ds->schema_error("$name: invalid regex `$arg`");
        return;
    }
    1;
}

sub chkarg_r_array {
    my ($self, $arg, $name, $minlen, $maxlen, $of) = @_;
    my $ds = $self->validator;
    return unless chkarg_required(@_);
    unless (ref($arg) eq 'ARRAY') {
        $ds->schema_error("$name: must be an array");
        return;
    }
    if (defined($minlen) && $minlen > 0 && defined($maxlen) && $maxlen == $minlen && @$arg != $minlen) {
        $ds->schema_error("$name: array must have $minlen element(s)");
        return;
    }
    if (defined($minlen) && $minlen > 0 && @$arg < $minlen) {
        $ds->schema_error("$name: array must have at least $minlen element(s)");
        return;
    }
    if (defined($maxlen) && $maxlen > 0 && @$arg > $maxlen) {
        $ds->schema_error("$name: array must have at most $maxlen element(s)");
        return;
    }
    if ($of) {
        for (0..@$arg-1) {
            return unless $of->($arg->[$_], "$name/$_");
        }
    }
    1;
}

sub chkarg_r_array_of_required {
    my ($self, $arg, $name, $minlen, $maxlen) = @_;
    $self->chkarg_r_array($arg, $name, $minlen, $maxlen,
                          sub { chkarg_required($self, @_) }
                      );
}

sub chkarg_r_array_of_str {
    my ($self, $arg, $name, $minlen, $maxlen) = @_;
    $self->chkarg_r_array($arg, $name, $minlen, $maxlen,
                          sub { chkarg_r_str($self, @_) }
                      );
}

sub chkarg_r_str_or_array_of_str {
    my ($self, $arg, $name, $minlen, $maxlen) = @_;
    my $ds = $self->validator;
    if (!ref($arg)) {
        return $self->chkarg_r_str($arg, $name);
    } elsif (ref($arg) eq 'ARRAY') {
        return $self->chkarg_r_array($arg, $name, $minlen, $maxlen,
                                     sub { chkarg_r_str($self, @_) }
                                 );
    } else {
        $ds->schema_error("$name: must be str or array");
        return;
    }
}

sub chkarg_r_array_of_regex {
    my ($self, $arg, $name, $minlen, $maxlen) = @_;
    $self->chkarg_r_array($arg, $name, $minlen, $maxlen,
                          sub { chkarg_r_regex($self, @_) }
                      );
}

sub chkarg_r_array_of_int {
    my ($self, $arg, $name, $minlen, $maxlen) = @_;
    $self->chkarg_r_array($arg, $name, $minlen, $maxlen,
                          sub { chkarg_r_int($self, @_) }
                      );
}

sub chkarg_r_int_or_array_of_int {
    my ($self, $arg, $name, $minlen, $maxlen) = @_;
    my $ds = $self->validator;
    if (!ref($arg)) {
        return $self->chkarg_r_int($arg, $name);
    } elsif (ref($arg) eq 'ARRAY') {
        return $self->chkarg_r_array($arg, $name, $minlen, $maxlen,
                                     sub { chkarg_r_int($self, @_) }
                                 );
    } else {
        $ds->schema_error("$name: must be str or array");
        return;
    }
}

sub chkarg_r_hash {
    my ($self, $arg, $name, $minlen, $maxlen, $keys_of, $values_of) = @_;
    my $ds = $self->validator;
    return unless chkarg_required(@_);
    unless (ref($arg) eq 'HASH') {
        $ds->schema_error("$name: must be a hash");
        return;
    }
    if (defined($minlen) && $minlen > 0 && defined($maxlen) && $maxlen == $minlen && keys(%$arg) != $minlen) {
        $ds->schema_error("$name: hash must have $minlen key(s)");
        return;
    }
    if (defined($minlen) && $minlen > 0 && keys(%$arg) < $minlen) {
        $ds->schema_error("$name: hash must have at least $minlen key(s)");
        return;
    }
    if (defined($maxlen) && $maxlen > 0 && keys(%$arg) > $maxlen) {
        $ds->schema_error("$name: hash must have at most $maxlen key(s)");
        return;
    }
    if ($keys_of) {
        for (keys %$arg) {
            return unless $keys_of->($_, "$name/$_");
        }
    }
    if ($values_of) {
        for (keys %$arg) {
            return unless $values_of->($arg->{$_}, "$name/$_");
        }
    }
    1;
}

sub chkarg_r_attrhash {
    my ($self, $arg, $name, $minlen, $maxlen) = @_;
    my $ds = $self->validator;
    $self->chkarg_r_hash($arg, $name, $minlen, $maxlen,
                         sub {
                             my ($arg, $name) = @_;
                             return unless $self->chkarg_r_str($arg, $name);
                             if ($arg !~ /\A([+^.*-])?([a-z_][a-z0-9_]{0,63})?(:\w+)?\z/) {
                                 $ds->schema_error("$name: invalid attribute name syntax `$arg`");
                                 return;
                             }
                             if (!$2 && !$3) {
                                 $ds->schema_error("$name: invalid attribute name `$arg`: no name/suffix");
                                 return;
                             }
                             1;
                         },
                         undef, # attr value can be anything
                     );
}

sub chkarg_r_obj {
    my ($self, $arg, $name, $isa) = @_;
    my $ds = $self->validator;
    return unless chkarg_required(@_);
    unless (blessed($arg)) {
        $ds->schema_error("$name: must be an object");
        return;
    }
    if ($isa && !$arg->isa($isa)) {
        $ds->schema_error("$name: object must isa $isa");
        return;
    }
    1;
}

sub chkarg_r_schema {
    my ($self, $arg, $name) = @_;
    my $ds = $self->validator;
    return unless $self->chkarg_required($arg, $name);
    my $ref = ref($arg);
    if (!$ref) {
        return unless $self->chkarg_r_typename($arg, $name);
    } elsif ($ref eq 'ARRAY') {
        if (@$arg == 0) {
            $ds->schema_error("$name: array schema must have at least 1 element");
            return;
        }
        return unless $self->chkarg_r_typename($arg->[0], "$name/0");
        for (1..@$arg-1) {
            my $ah = $arg->[$_];
            return unless $self->chkarg_r_attrhash($ah, "$name/$_");
        }
    } elsif ($ref eq 'HASH') {
        for my $k (keys %$arg) {
            if ($k eq 'type') {
                return unless $self->chkarg_r_typename($arg->{$k}, "$name/type");
            } elsif ($k eq 'attr_hashes') {
                for (0..@{ $arg->{$k} }-1) {
                    my $ah = $arg->{$k}[$_];
                    return unless $self->chkarg_r_attrhash($ah, "$name/attr_hashes/$_");
                }
            } elsif ($k eq 'def') {
                return unless $self->chkarg_r_hash($arg->{$k}, "$name/def");
                for (keys %{ $arg->{$k} }) {
                    return unless $self->chkarg_r_schema($arg->{$k}{$_}, "$name/def/$_");
                }
            } else {
                $ds->schema_error("$name: hash schema doesn't recognize key `$_`");
                return;
            }
        }
    } else {
        $ds->schema_error("$name: schema must be str/array/hash");
        return;
    }
    1;
}

sub chkarg_r_array_of_schema {
    my ($self, $arg, $name, $minlen, $maxlen) = @_;
    $self->chkarg_r_array($arg, $name, $minlen, $maxlen,
                          sub { chkarg_r_schema($self, @_) }
                      );
}



sub handle_pre_check_attrs {
    1;
}


sub sort_attr_hash_keys {
    my ($self, $attrhash) = @_;
    keys %$attrhash;
}


sub handle_type {
    my ($self, $data0, $attr_hashes0) = @_;
    my $has_err = 0;
    my $ds = $self->validator;

    #print "DEBUG: (before merge) handle_type($self, ".$self->_dump($data0).", ".$self->_dump($attr_hashes0).")\n";
    my $res = $ds->merge_attr_hashes($attr_hashes0);
    if (!$res->{success}) {
        $ds->schema_error("can't merge attrhashes: $res->{error}");
        return;
    }
    my $attr_hashes = $res->{result};
    #print "DEBUG: (after merge) handle_type($self, ".$self->_dump($data0).", ".$self->_dump($attr_hashes).")\n";

    my $data = $data0;
    for my $i (0..@$attr_hashes-1) {
        my $ah = $attr_hashes->[$i];
        if (defined($ah->{default}) && !defined($data)) {
            $ds->debug(sub { "Using default from attr_hash[$i]: " . $self->_perl($ah->{default}) }, 5);
            $data = $ah->{default};
        }
        last;
    }

    my $required  = grep { $_->{required}  || (defined($_->{set}) &&  $_->{set}) } @$attr_hashes;
    my $forbidden = grep { $_->{forbidden} || (defined($_->{set}) && !$_->{set}) } @$attr_hashes;
    if ($forbidden && $required) {
        $ds->schema_error("conflict between required and forbidden");
        return;
    } elsif (!defined($data)) {
        if ($required) {
            $ds->data_error("must be specified");
            return;
        } else {
            return 1;
        }
    } elsif ($forbidden) {
        $ds->data_error("must not be specified");
        return;
    }

    push @{ $ds->schema_pos }, 'type';
    $res = $self->handle_pre_check_attrs($data);
    if (!$res) { pop @{ $ds->schema_pos }; return }

    $ds->schema_pos->[-1] = 'attr_hashes';
    my $i = 0;
    my $generic_errmsg;
    my $generic_warnmsg;
    my $is_warning;
    for my $attr_hash (@$attr_hashes) {
        $ds->debug(sub { "Evaluating attr_hash[$i]: ".$self->_perl($attr_hash) }, 5);
        push @{ $ds->schema_pos }, $i, '';
        my @attrs = $self->sort_attr_hash_keys($attr_hash);
        foreach my $k (@attrs) {
            my $v = $attr_hash->{$k};
            my ($prefix, $name, $suffix) = $k =~ /^([!*+.^-])?([a-z_][a-z0-9_]*)?:?(.*)$/;
            my $attr_is_warning;

            if (!$name) {
                if ($suffix) {
                    if ($suffix eq 'errmsg') {
                        $generic_errmsg = $v;
                        next;
                    } elsif ($suffix eq 'warnmsg') {
                        $generic_warnmsg = $v;
                        next;
                    } elsif ($suffix =~ /^(comment|note)$/) {
                        next;
                    } elsif ($suffix eq 'warn') {
                        if (defined($is_warning)) {
                            $has_err++;
                            $ds->schema_error("conflict between :warn and :err");
                        } else {
                            $is_warning = 1;
                        }
                        next;
                    } elsif ($suffix eq 'err') {
                        if (defined($is_warning)) {
                            $has_err++;
                            $ds->schema_error("conflict between :warn and :err");
                        } else {
                            $is_warning = 0;
                        }
                        next;
                    } else {
                        $has_err++;
                        $ds->schema_error("unknown attributeless suffix `$suffix': $k");
                        next;
                    }
                } else {
                    $has_err++;
                    $ds->schema_error("invalid attribute `$k' (no name/suffix)");
                    next;
                }
            }

            next if $name =~ /^_/;
            if ($suffix) {
                if ($suffix =~ /^(comment|note|warnmsg|errmsg)$/) {
                    next;
                } elsif ($suffix eq 'warn') {
                        $attr_is_warning = 1;
                } elsif ($suffix eq 'err') {
                    $attr_is_warning = 0;
                } else {
                    $has_err++;
                    $ds->schema_error("unknown attribute suffix `$suffix': $k");
                }
            } else {
            }
            last if $ds->too_many_errors;

            next if $name =~ /^(required|forbidden|set|default)$/;

            my $meth_chk = "chkarg_attr_$name";
            my $meth_hdl = "handle_attr_$name";
            $ds->schema_pos->[-1] = $name;
            if ( $self->can($meth_hdl) ) {
                my $err_pos = @{ $ds->errors };
                $ds->debug( sub { "Entering sub $meth_chk, attr=$k, args=(" . $self->_dump($v) . ", '$name')" }, 5);
                my $res = $self->$meth_chk( $v, $name );
                $ds->debug( "Leaving  sub $meth_chk, attr=$k, res=" . ( $res // 0 ), 5);
                if ($res) {
                    $ds->debug( "Entering sub $meth_hdl, attr=$k", 5 );
                    $res = $self->$meth_hdl( $data, $v );
                    $ds->debug( "Leaving  sub $meth_hdl, attr=$k, res=" . ( $res // 0 ), 5);
                }
                if ( !$res ) {
                    if ($attr_is_warning) {
                        #$is_warning++;
                        # move errors to warnings
                        my @errs = splice @{ $ds->errors }, $err_pos;
                        my $warnmsg = $attr_hash->{"$name:warnmsg"};
                        if ( defined($warnmsg) ) {
                            my $f = $ds->config->gettext_function;
                            $ds->data_warn( ref($f) ? $f->($warnmsg) : $warnmsg );
                        } else {
                            push @{ $ds->warnings }, @errs;
                        }
                    } else {
                        $has_err++;
                        # replace default error message if supplied
                        my $errmsg = $attr_hash->{"$name:errmsg"};
                        if ( defined($errmsg) ) {
                            splice @{ $ds->errors }, $err_pos;
                            my $f = $ds->config->gettext_function;
                            $ds->data_error(
                                ref($f) ? $f->($errmsg) : $errmsg );
                        }
                    }
                    last if $ds->too_many_errors;
                }
            } else {
                $ds->schema_error("unknown attribute: $name");
                $has_err++;
                last if $ds->too_many_errors;
            }
        }
        $i++;
        pop @{ $ds->schema_pos };
        pop @{ $ds->schema_pos };
        last if $ds->too_many_errors;
    }
    pop @{ $ds->schema_pos };

    if ($is_warning) {
        $has_err = 0;
        push @{ $ds->warnings }, @{ $ds->errors };
        $ds->errors([]);
    }
    if ($generic_warnmsg && @{ $ds->warnings }) {
        $ds->warnings([]);
        $ds->data_warn($generic_warnmsg);
    }
    if ($generic_errmsg && @{ $ds->errors }) {
        $ds->errors([]);
        $ds->data_error($generic_errmsg);
    }
    !$has_err;
}

sub emitpl_pre_check_attrs {
    "";
}

sub emit_perl {
    my ($self, $attr_hashes0, $subname) = @_;
    my $ds = $self->validator;

    $subname //= "NONAME";
    my $perl = '';
    my $perl2;

    $perl .= $ds->emitpl_require('Data::Dumper');
    $perl .= "# schema: ".$self->short_english." ".$self->_dump($attr_hashes0)."\n";
    $perl .= 'sub '.$subname.' {'."\n";
    $perl .= '    my ($data, $datapos, $schemapos) = @_;'."\n";
    $perl .= '    if (!$datapos  ) { $datapos   = [] }'."\n";
    $perl .= '    if (!$schemapos) { $schemapos = [] }'."\n";
    $perl .= '    my (@errors, @warnings);'."\n";
    $perl .= "    L1: {\n";

    my $res = $ds->merge_attr_hashes($attr_hashes0);
    if (!$res->{success}) {
        $ds->schema_error("can't merge attrhashes: $res->{error}");
        return;
    }
    my $attr_hashes = $res->{result};

    for (@$attr_hashes) {
        if (defined($_->{default})) {
            $perl .= "\n    # default\n";
            $perl .= '$data //= '.$self->_perl($_->{default}).";\n";
            last;
        }
    }

    my $required  = grep { $_->{required}  || (defined($_->{set}) &&  $_->{set}) } @$attr_hashes;
    my $forbidden = grep { $_->{forbidden} || (defined($_->{set}) && !$_->{set}) } @$attr_hashes;
    if ($forbidden && $required) {
        $ds->schema_error("conflict between required and forbidden");
        return;
    } elsif ($required) {
        $perl .= "\n    # required\n";
        $perl .= '    if (!defined($data)) { '.$ds->emitpl_data_error("must be specified")." last L1 }\n";
    } elsif ($forbidden) {
        $perl .= "\n    # forbidden\n";
        $perl .= '    if (defined($data)) { '.$ds->emitpl_data_error("must not be specified")." last L1 } else { last }\n";
    } else {
        $perl .= "\n    # optional\n";
        $perl .= '    if (!defined($data)) { last }'."\n";
    }

    $perl .= "\n    # -- pre_check_attr\n";
    $perl .= '    push @$schemapos, "type";'."\n";
    $perl2 = $self->emitpl_pre_check_attrs();
    $perl .= join("\n", map { "    $_" } split "\n", $perl2)."\n";
    $perl .= '    pop @$schemapos;'."\n";

    my $i = 0;
    my $generic_errmsg;
    my $generic_warnmsg;
    my $is_warning;
    $perl .= '    push @$schemapos, ("attr_hashes", -1);'."\n";
    for my $attr_hash (@$attr_hashes) {
        $perl .= "\n    # -- attr_hashes[$i]\n";
        $perl .= '    $schemapos->[-1] = '.$i.";\n";
        $perl .= '    push @$schemapos, "";'."\n";
        my @attrs = $self->sort_attr_hash_keys($attr_hash);
        foreach my $k (@attrs) {
            my $v = $attr_hash->{$k};
            #print "DEBUG: [attr:$k start] \$perl tainted? ", tainted($perl), "\n";
            my ($prefix, $name, $suffix) = $k =~ /^([!*+.^-])?([a-z_][a-z0-9_]*)?:?(.*)$/;
            my $attr_is_warning;

            if (defined($name)) { ($name) = $name =~ /(.*)/ } # perl bug? somehow $name is tainted, while $k is not!

            if (!$name) {
                if ($suffix) {
                    if ($suffix eq 'errmsg') {
                        $generic_errmsg = $v;
                        next;
                    } elsif ($suffix eq 'warnmsg') {
                        $generic_warnmsg = $v;
                        next;
                    } elsif ($suffix =~ /^(comment|note)$/) {
                        next;
                    } elsif ($suffix eq 'warn') {
                        if (defined($is_warning)) {
                            $ds->schema_error("conflict between :warn and :err");
                        } else {
                            $is_warning = 1;
                        }
                        next;
                    } elsif ($suffix eq 'err') {
                        if (defined($is_warning)) {
                            $ds->schema_error("conflict between :warn and :err");
                        } else {
                            $is_warning = 0;
                        }
                        next;
                    } else {
                        $ds->schema_error("unknown attributeless suffix `$suffix': $k");
                        next;
                    }
                } else {
                    $ds->schema_error("invalid attribute `$k' (no name/suffix)");
                    next;
                }
            }

            next if $name =~ /^_/;
            if ($suffix) {
                if ($suffix =~ /^(comment|note|warnmsg|errmsg)$/) {
                    next;
                } elsif ($suffix eq 'warn') {
                    $attr_is_warning = 1;
                } elsif ($suffix eq 'err') {
                    $attr_is_warning = 0;
                } else {
                    $ds->schema_error("unknown attribute suffix `$suffix': $k");
                }
            } else {
            }

            next if $name =~ /^(required|forbidden|set|default)$/;

            my $meth_chk = "chkarg_attr_$name";
            my $meth_hdl = "emitpl_attr_$name";
            if ($self->can($meth_hdl)) {
                die "BUG: $meth_chk(".$self->_perl($v).", $name) doesn't return true"
                    unless $self->$meth_chk($v, $name);
                $perl2 = $self->$meth_hdl($v);
                return unless defined($perl2);
                my $errmsg = $attr_hash->{"$name:errmsg"};
                my $warnmsg = $attr_hash->{"$name:warnmsg"};
                $perl .= "\n    # --- attr: $name\n";
                $perl .= '    $schemapos->[-1] = '."'$k';\n";
                if (defined($errmsg) || defined($warnmsg) || $attr_is_warning) {
                    $perl .= $ds->emitpl_my('$pos1e');
                    $perl .= '    $pos1e = @errors;'."\n"
                }
                if (defined($warnmsg)) {
                    $perl .= $ds->emitpl_my('$pos1w');
                    $perl .= '    $pos1w = @warnings;'."\n"
                }
                $perl .= join("\n", map { "    $_" } split "\n", $perl2)."\n";
                if ($attr_is_warning) {
                    $perl .= '    push @warnings, (splice @errors, $pos1e);'."\n";
                }
                if (defined($errmsg)) {
                    my $f = $ds->config->gettext_function;
                    $perl .= $ds->emitpl_my('$pos2e');
                    $perl .= '    $pos2e = @errors;'."\n";
                    $perl .= '    if ($pos2e != $pos1e) { splice @errors, $pos1e; '.$ds->emitpl_data_error(ref($f) ? $f->($errmsg) : $errmsg)." }\n";
                }
                if (defined($warnmsg)) {
                    my $f = $ds->config->gettext_function;
                    $perl .= $ds->emitpl_my('$pos2w');
                    $perl .= '    $pos2w = @warnings;'."\n";
                    $perl .= '    if ($pos2w != $pos1w) { splice @warnings, $pos1w; '.$ds->emitpl_data_warn(ref($f) ? $f->($warnmsg) : $warnmsg)." }\n";
                }
            } else {
                $ds->schema_error("unknown attribute `$name' for type ".$self->short_english);
                return;
            }
            #print "DEBUG: [attr:$k end] \$perl tainted? ", tainted($perl), "\n";
        }
        $perl .= '    pop @$schemapos;'."\n";
        $i++;
    }
    $perl .= '    pop @$schemapos;'."\n";
    $perl .= '    pop @$schemapos;'."\n";
    $perl .= "\n    } # L1\n";
    if ($is_warning) { $perl .= '    push @warnings, @errors; @errors  = ();'."\n" }
    if ($generic_warnmsg) { $perl .= '    @warnings = (); '.$ds->emitpl_data_warn ($generic_warnmsg)."\n" }
    if ($generic_errmsg)  { $perl .= '    @errors   = (); '.$ds->emitpl_data_error($generic_errmsg )."\n" }
    $perl .= '    (\@errors, \@warnings);'."\n";
    $perl .= "}\n\n";
    $perl;
    #print "DEBUG: [end of emit_perl] \$perl tainted? ", tainted($perl), "\n";
}

sub chkarg_attr_note { 1   }
sub handle_attr_note { 1   }
sub emitpl_attr_note { " " }

__make_attr_alias(note => qw/comment/);


sub english {
    "base";
}


sub short_english {
    "base";
}


__PACKAGE__->meta->make_immutable;
no Moose;
1;

__END__
=pod

=head1 NAME

Data::Schema::Type::Base - Base class for Data::Schema type handler

=head1 VERSION

version 0.135

=head1 SYNOPSIS

    use Data::Schema;

=head1 DESCRIPTION

This is the base class for all type handlers. Normally you wouldn't use this
type but one of its subclasses.

=head1 METHODS

=head2 handle_pre_check_attrs($data)

This method is called by C<handle_type()> before checking type attributes. It
should return true if checking passes or false if checking fails. By default it
does nothing but returns true. Override this method if you want to add
additional checking.

=head2 sort_attr_keys($attrhash)

Return attribute keys in execute order. Some type might need some attributes to
be executed first (because they have some side-effect, etc), e.g. DST::Hash
overrides this to put 'allow_extra_keys' first, because later 'keys' needs to
know the state of 'allow_extra_keys'.

Otherwise, you can just return the keys in any/default order (the default
implementation).

=head2 handle_type($data, $attrhash, ...)

Check data against type (and all type attributes). Returns 1 if success, 0 if
fails. You normally do not need to override this method. This method is called
by the validator (Data::Schema object).

Also handle the 'required' and 'forbidden' (and their alias: 'set') attributes,
these are special so they're handled here. All the other attributes are handled
using 'handle_attr_XXX' methods.

=head2 english($attrhash, ...)

Show an English representation of this data type.

=head2 short_english()

Show an English representation of this data type.

=head1 TYPE ATTRIBUTES

Attributes that are handled by the Base:

=head2 required

Aliases: set=>1

If set to 1, require that data be defined. Otherwise, allow undef (the
default behaviour).

By default, undef will pass even elaborate schema:

 ds_validate(undef, "int"); # valid
 ds_validate(undef, [int => {min=>0, max=>10, divisible_by=>3}]); # valid!

However:

 ds_validate(undef, [int=>{required=>1}]); # invalid

This behaviour's rationale is much like NULLs in SQL: we *can't* validate
something that is unknown/unset.

=head2 forbidden

Aliases: set=>0

This is the opposite of required, requiring that data be not defined (i.e.
undef).

 ds_validate(1, [int=>{forbidden=>1}]); # invalid
 ds_validate(undef, [int=>{forbidden=>1}]); # valid

=head2 set

Alias for required or forbidden. set=>1 equals required=>1, while set=>0
equals forbidden=>1.

=head2 default

Supply a default value.

 ds_validate(undef, [int => {required=>1}]); # invalid, data undefined
 ds_validate(undef, [int => {required=>1, default=>3}]); # valid

=head1 AUTHOR

  Steven Haryanto <stevenharyanto@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2009 by Steven Haryanto.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

