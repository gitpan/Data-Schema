package Data::Schema::Type::Base;
our $VERSION = '0.12';


# ABSTRACT: Base class for Data::Schema type handler


use Moose;
use Data::Dumper;
use Scalar::Util qw/tainted/;

has 'validator' => (is => 'rw');
with 'Data::Schema::Type::Printable';

sub _dump {
    _perl(@_);
}

sub _emitpl_dump {
    _emitpl_perl(@_);
}

sub _emitpl_def_dump {
    my ($self) = @_;
    return '' if $self->validator->stash->{C_sub_dump}++;
'require Data::Dumper;
local $Data::Dumper::Indent = 0;
local $Data::Dumper::Terse = 1;
local $Data::Dumper::Sortkeys = 1;
local $Data::Dumper::Purity = 0;
'
}

sub _emitpl_perl {
    my ($self, $var, $lit) = @_;
    "Data::Dumper->new([".($lit ? $var : $self->_dump($var))."]".")->Indent(0)->Terse(1)->Sortkeys(1)->Purity(0)->Dump()";
}

sub _perl {
    my ($self, $val) = @_;
    local $Data::Dumper::Indent = 0;
    local $Data::Dumper::Terse = 1;
    local $Data::Dumper::Sortkeys = 1;
    local $Data::Dumper::Purity = 0;
    Dumper($val);
}



sub handle_pre_check_attrs {
    1;
}


sub sort_attr_hash_keys {
    my ($self, $attrhash) = @_;
    keys %$attrhash;
}


sub handle_type {
    my ($self, $data, $attr_hashes0) = @_;
    my $has_err = 0;
    my $ds = $self->validator;

    #print "DEBUG: (before merge) handle_type($self, ".$self->_dump($data).", ".$self->_dump($attr_hashes0).")\n";
    my $res = $ds->merge_attr_hashes($attr_hashes0);
    if (!$res->{success}) {
        $ds->schema_error("can't merge attrhashes: $res->{error}");
        return;
    }
    my $attr_hashes = $res->{result};
    #print "DEBUG: (after merge) handle_type($self, ".$self->_dump($data).", ".$self->_dump($attr_hashes).")\n";

    my $required  = grep { $_->{required}  || (defined($_->{set}) &&  $_->{set}) } @$attr_hashes;
    my $forbidden = grep { $_->{forbidden} || (defined($_->{set}) && !$_->{set}) } @$attr_hashes;
    if ($forbidden && $required) {
        $ds->schema_error("'required/set=1' AND 'forbidden/set=0' cannot be specified together");
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
    for my $attr_hash (@$attr_hashes) {
        #print "DEBUG: evaluating attr_hash[$i]: ".$self->_dump($attr_hash).")\n";
        push @{ $ds->schema_pos }, $i, '';
        my @attrs = $self->sort_attr_hash_keys($attr_hash);
        foreach my $k (@attrs) {
            my ($prefix, $name, $suffix) = $k =~ /^([!*+.^-])?([a-z][a-z0-9_]*)?:?(.*)$/;

            if (!$name) {
		if ($suffix) {
		    if ($suffix eq 'errmsg') {
			$generic_errmsg = $attr_hash->{$k};
			next;
		    } else {
			$has_err++;
			$ds->schema_error("unknown attributeless suffix `$suffix': $k");
			next;
		    }
		} else {
		    $has_err++;
		    $ds->schema_error("invalid attribute `$k'");
		    next;
		}
	    }

            next if $name =~ /^(ui)$/;
            if ($suffix && $suffix !~ /^(errmsg)$/) {
                $has_err++;
                $ds->schema_error("unknown attribute suffix `$suffix': $k");
            }
            last if $ds->too_many_errors;

            next if $suffix;
            next if $name =~ /^(required|forbidden|set)$/;

            my $meth = "handle_attr_$name";
            $ds->schema_pos->[-1] = $name;
            if ($self->can($meth)) {
                my $err_pos = @{ $ds->errors };
                if (!$self->$meth($data, $attr_hash->{$k})) {
                    $has_err++;

                    # replace default error message if supplied
                    my $errmsg = $attr_hash->{"$name:errmsg"};
                    if (defined($errmsg)) {
			splice @{ $ds->errors }, $err_pos;
                        my $f = $ds->config->gettext_function;
                        $ds->data_error(ref($f) ? $f->($errmsg) : $errmsg);
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

    if ($generic_errmsg) {
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
    $subname //= "NONAME";
    my $perl = '';
    my $perl2;

    $perl .= "# schema: ".$self->short_english." ".$self->_dump($attr_hashes0)."\n";
    $perl .= 'sub '.$subname.' {'."\n";
    $perl .= '    my ($data, $datapos, $schemapos) = @_;'."\n";
    $perl .= '    if (!$datapos  ) { $datapos   = [] }'."\n";
    $perl .= '    if (!$schemapos) { $schemapos = [] }'."\n";
    $perl .= '    my @errors;'."\n";
    $perl .= "    L1: {\n";

    my $ds = $self->validator;

    my $res = $ds->merge_attr_hashes($attr_hashes0);
    if (!$res->{success}) {
        $ds->schema_error("can't merge attrhashes: $res->{error}");
        return;
    }
    my $attr_hashes = $res->{result};

    my $required  = grep { $_->{required}  || (defined($_->{set}) &&  $_->{set}) } @$attr_hashes;
    my $forbidden = grep { $_->{forbidden} || (defined($_->{set}) && !$_->{set}) } @$attr_hashes;
    if ($forbidden && $required) {
        $ds->schema_error("'required/set=1' AND 'forbidden/set=0' cannot be specified together");
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
    $perl .= '    push @$schemapos, ("attr_hashes", -1);'."\n";
    for my $attr_hash (@$attr_hashes) {
        $perl .= "\n    # -- attr_hashes[$i]\n";
        $perl .= '    $schemapos->[-1] = '.$i.";\n";
        $perl .= '    push @$schemapos, "";'."\n";
        my @attrs = $self->sort_attr_hash_keys($attr_hash);
        foreach my $k (@attrs) {
	    #print "DEBUG: [attr:$k start] \$perl tainted? ", tainted($perl), "\n";
            my ($prefix, $name, $suffix) = $k =~ /^([!*+.^-])?([a-z][a-z0-9_]*)?:?(.*)$/;

	    if (defined($name)) { ($name) = $name =~ /(.*)/ } # perl bug? somehow $name is tainted, while $k is not!

            if (!$name) {
        		if ($suffix) {
        		    if ($suffix eq 'errmsg') {
            			$generic_errmsg = $attr_hash->{$k};
            			next;
        		    } else {
            			$ds->schema_error("unknown attributeless suffix `$suffix': $k");
                		next;
                    }
            	} else {
        		    $ds->schema_error("invalid attribute `$k'");
            	    next;
            	}
            }

            next if $name =~ /^(ui)$/;
            if ($suffix && $suffix !~ /^(errmsg)$/) {
                $ds->schema_error("unknown attribute suffix `$suffix': $k");
                return;
            }

            next if $suffix;
            next if $name =~ /^(required|forbidden|set)$/;

            my $meth = "emitpl_attr_$name";
            if ($self->can($meth)) {
                $perl2 = $self->$meth($attr_hash->{$k});
                return unless defined($perl2);
                my $errmsg = $attr_hash->{"$name:errmsg"};
                $perl .= "\n    # --- attr: $name\n";
                $perl .= '    $schemapos->[-1] = '."'$k';\n";
                if (defined($errmsg)) { $perl .= '    my $pos1 = @errors;'."\n" }
                $perl .= join("\n", map { "    $_" } split "\n", $perl2)."\n";
                if (defined($errmsg)) {
                    my $f = $ds->config->gettext_function;
                    $perl .= '    my $pos2 = @errors;'."\n";
                    $perl .= '    if ($pos2 != $pos1) { splice @errors, $pos1; '.$ds->emitpl_data_error(ref($f) ? $f->($errmsg) : $errmsg)." }\n";
                }
            } else {
                $ds->schema_error("unknown attribute `$name'");
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
    if ($generic_errmsg) { $perl .= '    @errors = (); '.$ds->emitpl_data_error($generic_errmsg)."\n" }
    $perl .= '    (\@errors);'."\n";
    $perl .= "}\n\n";
    $perl;
    #print "DEBUG: [end of emit_perl] \$perl tainted? ", tainted($perl), "\n";
}


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

version 0.12

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

=head1 AUTHOR

  Steven Haryanto <stevenharyanto@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2009 by Steven Haryanto.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

