package Data::Schema::Type::Comparable;
our $VERSION = '0.132';


# ABSTRACT: Role for comparable types


use Moose::Role;
with 'Data::Schema::Type::Printable';
requires map { ("_$_", "_emitpl_$_") } qw/equal/;


sub chkarg_attr_one_of {
    my ($self, $arg, $name) = @_;
    $self->chkarg_r_array_of_required($arg, $name);
}

sub handle_attr_one_of {
    my ($self, $data, $arg) = @_;
    for (@$arg) {
        return 1 if $self->_equal($data, $_);
    }
    my $msg;
    if (@$arg == 1) {
        $msg = "data must be ".$self->_dump($arg->[0]);
    } elsif (@$arg <= 10) {
        $msg = "data must be one of ".$self->_dump($arg);
    } else {
        $msg = "data doesn't belong to a list of valid values";
    }
    $self->validator->data_error($msg);
    0;
}

sub emitpl_attr_one_of {
    my ($self, $arg) = @_;
    my $perl = '';

    $perl .= $self->validator->emitpl_my('$arg', '$found');
    $perl .= '$arg = '.$self->_perl($arg).';'."\n";
    $perl .= '$found=0;'."\n";
    $perl .= 'for (@$arg) {'."\n";
    $perl .= '    if ('.$self->_emitpl_equal('$data', '$_').') { $found=1; last }'."\n";
    $perl .= '}'."\n";
    $perl .= 'unless ($found) {'."\n";
    $perl .= '    my $msg;'."\n";
    $perl .= '    if (@$arg == 1) { $msg = "data must be ".'.$self->_emitpl_dump('$arg->[0]', 1)." }\n";
    $perl .= '    elsif (@$arg <= 10) { $msg = "data must be one of ".'.$self->_emitpl_dump('$arg', 1)." }\n";
    $perl .= '    else { $msg = "data doesn\'t belong to a list of valid values" }'."\n";
    $perl .= '    '.$self->validator->emitpl_data_error('$msg', 1)."\n";
    $perl .= "}\n";
    $perl;
}

Data::Schema::Type::Base::__make_attr_alias(one_of => qw/is_one_of/);


sub chkarg_attr_not_one_of { chkarg_attr_one_of(@_) }

sub handle_attr_not_one_of {
    my ($self, $data, $arg) = @_;
    for (@$arg) {
        if ($self->_equal($data, $_)) {
            my $msg;
            if (@$arg == 1) {
                $msg = "data must not be ".$self->_dump($arg->[0]);
            } elsif (@$arg <= 10) {
                $msg = "data must not be one of ".$self->_dump($arg);
            } else {
                $msg = "data belongs to a list of invalid values";
            }
            $self->validator->data_error($msg);
            return 0;
        }
    }
    1;
}

sub emitpl_attr_not_one_of {
    my ($self, $arg) = @_;
    my $perl = '';

    $perl .= $self->validator->emitpl_my('$arg', '$found');
    $perl .= '$arg = '.$self->_perl($arg).';'."\n";
    $perl .= '$found=0;'."\n";
    $perl .= 'for (@$arg) {'."\n";
    $perl .= '    if ('.$self->_emitpl_equal('$data', '$_').') { $found=1; last }'."\n";
    $perl .= '}'."\n";
    $perl .= 'if ($found) {'."\n";
    $perl .= '    my $msg;'."\n";
    $perl .= '    if (@$arg == 1) { $msg = "data must be ".'.$self->_emitpl_dump('$arg->[0]', 1)." }\n";
    $perl .= '    elsif (@$arg <= 10) { $msg = "data must be one of ".'.$self->_emitpl_dump('$arg', 1)." }\n";
    $perl .= '    else { $msg = "data belongs to a list of invalid values" }'."\n";
    $perl .= '    '.$self->validator->emitpl_data_error('$msg', 1)."\n";
    $perl .= "}\n";
    $perl;
}

Data::Schema::Type::Base::__make_attr_alias(not_one_of => qw/isnt_one_of/);


sub chkarg_attr_is {
    my ($self, $arg, $name) = @_;
    $self->chkarg_required($arg, $name);
}

sub handle_attr_is {
    my ($self, $data, $arg) = @_;
    $self->handle_attr_one_of($data, [$arg]);
}

sub emitpl_attr_is {
    my ($self, $arg) = @_;
    $self->emitpl_attr_one_of([$arg]);
}


sub chkarg_attr_isnt { chkarg_attr_is(@_) }

sub handle_attr_isnt {
    my ($self, $data, $arg) = @_;
    $self->handle_attr_not_one_of($data, [$arg]);
}

sub emitpl_attr_isnt {
    my ($self, $arg) = @_;
    $self->emitpl_attr_not_one_of([$arg]);
}

Data::Schema::Type::Base::__make_attr_alias(isnt => qw/not/);

no Moose::Role;
1;

__END__
=pod

=head1 NAME

Data::Schema::Type::Comparable - Role for comparable types

=head1 VERSION

version 0.132

=head1 SYNOPSIS

    use Data::Schema;

=head1 DESCRIPTION

This is the comparable role. It provides attributes like is,
one_of, etc. It is used by most types, for example 'str', all numeric types,
etc.

Role consumer must provide method '_equal' which takes two values and returns 0
or 1 depending on whether the values are equal.

=head1 TYPE ATTRIBUTES

=head2 one_of => [value1, ...]

Aliases: is_one_of

Require that the data is one of the specified choices.

=head2 not_one_of => [value1, ...]

Aliases: isnt_one_of

Require that the data is not listed in one of the specified "blacklists".

=head2 is => value

A convenient attribute for B<one_of> when there is only one choice.

=head2 isnt => value

Aliases: not

A convenient attribute for B<not_one_of> when there is only one item in the
blacklist.

=head1 AUTHOR

  Steven Haryanto <stevenharyanto@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2009 by Steven Haryanto.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

