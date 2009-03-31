package Data::Schema::Type::Base;

use Moose;
use Data::Dumper;

=head1 NAME

Data::Schema::Type::Base - Base class for Data::Schema type handler

=head1 SYNOPSIS

    use Data::Schema;

=head1 DESCRIPTION

This is the base class for most type handlers. It provides some comparison
attributes like C<is>, C<one_of>, C<min>, C<max>, etc. (see B<TYPE ATTRIBUTES>
section below for complete list). Normally you wouldn't use this type but one of
its subclasses.

=cut

has 'validator' => (is => 'rw');

# utility routines
sub _dmp {
    my $var = shift;
    local $Data::Dumper::Indent = 0;
    local $_ = Dumper($var);
    s/^\$VAR1 = //;
    s/;$//;
    $_;
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

    my $required = grep { $_->{required} } @$attr_hashes;
    if (!defined($data)) {
        if ($required) {
            $validator->log_error("data error: missing required");
            return;
        } else {
            return 1;
        }
    }

    push @{ $validator->schema_pos }, 'type';
    $res = $self->handle_pre_check_attrs($data);
    if (!$res) { pop @{ $validator->schema_pos }; return }

    $validator->schema_pos->[-1] = 'attr_hashes';
    my $i = 0;
    for my $attr_hash (@$attr_hashes) {
        push @{ $validator->schema_pos }, $i, '';
        foreach my $k (keys %$attr_hash) {
            my ($name, $suffix) = $k =~ /^([a-z][a-z0-9_]*)\.?(.*)$/;

            if (!$name) {
                $has_err++;
                $validator->log_error("schema error: invalid attribute name `$name': $k");
            }
            if ($suffix && $suffix !~ /^(errmsg)$/) {
                $has_err++;
                $validator->log_error("schema error: unknown attribute suffix `$suffix': $k");
            }
            last if $validator->too_many_errors;

            next if $suffix;
            next if $name =~ /^(required)$/;

            my $meth = "handle_attr_$name";
            $validator->schema_pos->[-1] = $name;
            if ($self->can($meth)) {
                my $err_pos = @{ $validator->errors };
                if (!$self->$meth($data, $attr_hash->{$name})) {
                    $has_err++;

                    # replace default error message if supplied
                    my $errmsg = $attr_hash->{"$name.errmsg"};
                    if (defined($errmsg)) {
                        splice @{ $validator->errors }, $err_pos;
                        my $f = $validator->config->{gettext_function};
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

=head1 TYPE ATTRIBUTES

=head2 one_of => [value1, ...]

Require that the data is one of the specified choices.

Synonyms: is_one_of

=cut

sub handle_attr_one_of {
    my ($self, $data, $arg) = @_;
    for (@$arg) {
        my $res = $self->cmp($data, $_);
        return 1 if defined($res) && $res == 0;
    }
    my $msg;
    if (@$arg == 1) {
        $msg = "data must be "._dmp($arg->[0]);
    } elsif (@$arg <= 10) {
        $msg = "data must be one of [".join(", ", map {_dmp($_)} @$arg)."]";
    } else {
        $msg = "data doesn't belong to a list of valid values";
    }
    $self->validator->log_error($msg);
    0;
}

# aliases
sub handle_attr_is_one_of { handle_attr_one_of(@_) }

=head2 not_one_of => [value1, ...]

Require that the data is not listed in one of the specified "blacklists".

Synonyms: isnt_one_of

=cut

sub handle_attr_not_one_of {
    my ($self, $data, $arg) = @_;
    for (@$arg) {
        my $res = $self->cmp($data, $_);
        if (defined($res) && $res == 0) {
            my $msg;
            if (@$arg == 1) {
                $msg = "data must not be "._dmp($arg->[0]);
            } elsif (@$arg <= 10) {
                $msg = "data must not be one of [".join(", ", map {_dmp($_)} @$arg)."]";
            } else {
                $msg = "data belongs to a list of invalid values";
            }
            $self->validator->log_error($msg);
            return 0;
        }
    }
    1;
}

# aliases
sub handle_attr_isnt_one_of { handle_attr_not_one_of(@_) }

=head2 is => value

A convenient attribute for B<one_of> when there is only one choice.

=cut

sub handle_attr_is {
    my ($self, $data, $arg) = @_;
    $self->handle_attr_one_of($data, [$arg]);
}

=head2 isnt => value

A convenient attribute for B<not_one_of> when there is only one item in the
blacklist.

Synonyms: not

=cut

# convenience method for only a single invalid value
sub handle_attr_isnt {
    my ($self, $data, $arg) = @_;
    $self->handle_attr_not_one_of($data, [$arg]);
}

# aliases
sub handle_attr_not { handle_attr_isnt(@_) }

=head2 min => MIN

Require that the value is not less than some specified minimum.

Synonyms: ge

=cut

sub handle_attr_min {
    my ($self, $data, $arg) = @_;
    my $res = $self->cmp($data, $arg);
    if (!defined($res)) {
        $self->validator->log_error("min/max is not defined for this type");
        return 0;
    }
    if ($res < 0) {
        $self->validator->log_error("value too small, min is $arg");
        return 0;
    }
    1;
}

# aliases
sub handle_attr_ge { handle_attr_min(@_) }

=head2 minex => MIN

Require that the value is not less or equal than some specified minimum.

Synonyms: gt

=cut

sub handle_attr_minex {
    my ($self, $data, $arg) = @_;
    my $res = $self->cmp($data, $arg);
    if (!defined($res)) {
        $self->validator->log_error("min/max is not defined for this type");
        return 0;
    }
    if ($res <= 0) {
        $self->validator->log_error("value must be greater than $arg");
        return 0;
    }
    1;
}

# aliases
sub handle_attr_gt { handle_attr_minex(@_) }

=head2 max => MAX

Require that the value is less or equal than some specified maximum.

Synonyms: le

=cut

sub handle_attr_max {
    my ($self, $data, $arg) = @_;
    my $res = $self->cmp($data, $arg);
    if (!defined($res)) {
        $self->validator->log_error("min/max is not defined for this type");
        return 0;
    }
    if ($res > 0) {
        $self->validator->log_error("value too large, max is $arg");
        return 0;
    }
    1;
}

# aliases
sub handle_attr_le { handle_attr_max(@_) }

=head2 maxex => MAX

Require that the value is less than some specified maximum.

Synonyms: lt

=cut

sub handle_attr_maxex {
    my ($self, $data, $arg) = @_;
    my $res = $self->cmp($data, $arg);
    if (!defined($res)) {
        $self->validator->log_error("min/max is not defined for this type");
        return 0;
    }
    if ($res >= 0) {
        $self->validator->log_error("value must be less than $arg");
        return 0;
    }
    1;
}

# aliases
sub handle_attr_lt { handle_attr_maxex(@_) }

=head2 between => [MIN, MAX]

A convenient attribut to combine B<min> and B<max>.

=cut

sub handle_attr_between {
    my ($self, $data, $arg) = @_;
    $self->handle_attr_min($data, $arg->[0]) &&
    $self->handle_attr_max($data, $arg->[1]);
}

=head1 AUTHOR

Steven Haryanto, C<< <steven at masterweb.net> >>

=head1 COPYRIGHT & LICENSE

Copyright 2009 Steven Haryanto, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut

__PACKAGE__->meta->make_immutable;
1;
