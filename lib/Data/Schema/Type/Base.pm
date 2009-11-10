package Data::Schema::Type::Base;

use Moose;
use Data::Dumper;

=head1 NAME

Data::Schema::Type::Base - Base class for Data::Schema type handler

=head1 SYNOPSIS

    use Data::Schema;

=head1 DESCRIPTION

This is the base class for most type handlers. Normally you wouldn't use this
type but one of its subclasses.

=cut

has 'validator' => (is => 'rw');
with 'Data::Schema::Type::Printable';

sub _dump {
    my ($self, $val) = @_;
    local $Data::Dumper::Indent = 0;
    local $Data::Dumper::Terse = 1;
    local $Data::Dumper::Sortkeys = 1;
    local $Data::Dumper::Purity = 0;
    Dumper($val);
}

=head1 METHODS

=head2 handle_pre_check_attrs($data)

This method is called by C<handle_type()> before checking type attributes. It
should return true if checking passes or false if checking fails. By default it
does nothing but returns true. Override this method if you want to add
additional checking.

=cut


sub handle_pre_check_attrs {
    1;
}

=head2 handle_type($data, $attrhash, ...)

Check data against type (and all type attributes). Returns 1 if success, 0 if
fails. You normally do not need to override this method. This method is called
by the validator (Data::Schema object).

Also handle the 'required' and 'forbidden' (and their alias: 'set') attributes,
these are special so they're handled here. All the other attributes are handled
using 'handle_attr_XXX' methods.

=cut

sub handle_type {
    my ($self, $data, $attr_hashes0) = @_;
    my $has_err = 0;

    my $validator = $self->validator;

    my $res = $validator->merge_attr_hashes($attr_hashes0);
    if (!$res->{success}) {
        $validator->log_error("schema error: can't merge attrhashes: $res->{error}");
        return;
    }
    my $attr_hashes = $res->{result};

    my $required  = grep { $_->{required}  || (defined($_->{set}) &&  $_->{set}) } @$attr_hashes;
    my $forbidden = grep { $_->{forbidden} || (defined($_->{set}) && !$_->{set}) } @$attr_hashes;
    if ($forbidden && $required) {
        $validator->log_error("schema error: 'required/set=1' AND 'forbidden/set=0' cannot be specified together");
        return;
    } elsif (!defined($data)) {
        if ($required) {
            $validator->log_error("data error: must be specified because schema says 'required/set=1'");
            return;
        } else {
            return 1;
        }
    } elsif ($forbidden) {
        $validator->log_error("data error: data must not be specified because schema says 'forbidden/set=1'");
        return;
    }

    push @{ $validator->schema_pos }, 'type';
    $res = $self->handle_pre_check_attrs($data);
    if (!$res) { pop @{ $validator->schema_pos }; return }

    $validator->schema_pos->[-1] = 'attr_hashes';
    my $i = 0;
    for my $attr_hash (@$attr_hashes) {
        push @{ $validator->schema_pos }, $i, '';
        foreach my $k (keys %$attr_hash) {
            my ($prefix, $name, $suffix) = $k =~ /^([!*+.^-])?([a-z][a-z0-9_]*)\.?(.*)$/;

            if (!$name) {
                $has_err++;
                $validator->log_error("schema error: invalid attribute name `$name': $k");
            }
            next if $name =~ /^(ui)$/;
            if ($suffix && $suffix !~ /^(errmsg)$/) {
                $has_err++;
                $validator->log_error("schema error: unknown attribute suffix `$suffix': $k");
            }
            last if $validator->too_many_errors;

            next if $suffix;
            next if $name =~ /^(required|forbidden|set)$/;

            my $meth = "handle_attr_$name";
            $validator->schema_pos->[-1] = $name;
            if ($self->can($meth)) {
                my $err_pos = @{ $validator->errors };
                if (!$self->$meth($data, $attr_hash->{$k})) {
                    $has_err++;

                    # replace default error message if supplied
                    my $errmsg = $attr_hash->{"$name.errmsg"};
                    if (defined($errmsg)) {
                        splice @{ $validator->errors }, $err_pos;
                        my $f = $validator->config->gettext_function;
                        $validator->log_error(ref($f) ? $f->($errmsg) : $errmsg);
                    }

                    last if $validator->too_many_errors;
                }
            } else {
                $validator->log_error("schema error: unknown attribute: $name");
                $has_err++;
                last if $validator->too_many_errors;
            }
        }
        $i++;
        pop @{ $self->validator->schema_pos };
        pop @{ $self->validator->schema_pos };
        last if $validator->too_many_errors;
    }
    pop @{ $validator->schema_pos };
    !$has_err;
}

=head2 english($attrhash, ...)

Show an English representation of this data type.

=cut

sub english {
    "base";
}

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
