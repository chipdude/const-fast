package Const::Fast;

use 5.008;
use strict;
use warnings FATAL => 'all';

use Scalar::Util qw/reftype blessed/;
use Carp qw/croak/;
use Sub::Exporter -setup => { exports => [qw/const/], groups => { default => [qw/const/] } };
use Storable qw/dclone/;

## no critic (RequireArgUnpacking, ProhibitAmpersandSigils)
# The use of $_[0] is deliberate and essential, to be able to use it as an lvalue and to keep the refcount down.

sub _make_readonly {
	my (undef, $dont_clone) = @_;
	if (my $reftype = reftype $_[0] and not blessed($_[0]) and not &Internals::SvREADONLY($_[0])) {
		my $needs_cloning = !$dont_clone && &Internals::SvREFCNT($_[0]) > 1;
		$_[0] = dclone($_[0]) if $needs_cloning;
		&Internals::SvREADONLY($_[0], 1);
		if ($reftype eq 'SCALAR' || $reftype eq 'REF') {
			_make_readonly(${ $_[0] }, 1);
		}
		elsif ($reftype eq 'ARRAY') {
			_make_readonly($_) for @{ $_[0] };
		}
		elsif ($reftype eq 'HASH') {
			&Internals::hv_clear_placeholders($_[0]);
			_make_readonly($_) for values %{ $_[0] };
		}
	}
	Internals::SvREADONLY($_[0], 1);
	return;
}

## no critic (ProhibitSubroutinePrototypes, ManyArgs)
sub const(\[$@%]@) {
	my (undef, @args) = @_;
	croak 'Attempt to reassign a readonly variable' if &Internals::SvREADONLY($_[0]);
	if (reftype $_[0] eq 'SCALAR') {
		croak 'No value for readonly variable' if @args == 0;
		croak 'Too many arguments in readonly assignment' if @args > 1;
		${ $_[0] } = $args[0];
	}
	elsif (reftype $_[0] eq 'ARRAY') {
		@{ $_[0] } = @args;
	}
	elsif (reftype $_[0] eq 'HASH') {
		croak 'Odd number of elements in hash assignment' if @args % 2;
		%{ $_[0] } = @args;
	}
	else {
		croak 'Can\'t make variable readonly';
	}
	_make_readonly($_[0], 1);
	return;
}

1;    # End of Const::Fast

# ABSTRACT: Facility for creating read-only scalars, arrays, and hashes

__END__

=head1 SYNOPSIS

 use Const::Fast;

 const my $foo => 'a scalar value';
 const my @bar => qw/a list value/;
 const my %buz => (a => 'hash', of => 'something');

=head1 SUBROUTINES/METHODS

=head2 const $var, $value

=head2 const @var, @value...

=head2 const %var, %value...

This the only function of this module and it is exported by default. It takes a scalar, array or hash lvalue as first argument, and a list of one or more values depending on the type of the first argument as the value for the variable. It will set the variable to that value and subsequently make it readonly. Arrays and hashes will be made deeply readonly.

Exporting is done using Sub::Exporter for flexibility on import.

=head1 RATIONALE

This module was written because I stumbled on some serious issues of L<Readonly> that aren't easily fixable without breaking backwards compatibility in subtle ways. In particular Readonly's use of ties is a source of subtle bugs and bad performance. Instead, this module uses the builtin readonly feature of perl, making access to the variables just as fast as any normal variable without the weird side-effects of ties. Readonly can do the same for scalars when Readonly::XS is installed, but chooses not to do so in the most common case. This may change in the future if someone takes up maintenance of Readonly, and the two modules may be convergence if that happens.

=head1 CAVEATS

Perl doesn't distinguish between restricted hashes and readonly hashes. This means that:

 use Const::Fast;
 const my %a => (foo => 1, bar => 2);
 say 1 unless $a{baz}

Will give the error "Attempt to access disallowed key 'baz' in a restricted hash". You have to use C<exists $a{baz}> instead. This is a limitation of perl that can hopefully be solved in the future.
 
=head1 ACKNOWLEDGEMENTS

The interface for this module was inspired by Eric Roode's L<Readonly>. The implementation is inspired by doing everything the opposite way Readonly does it.

=cut
