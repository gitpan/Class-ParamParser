=head1 NAME

Class::ParamParser - Provides complex parameter list parsing.

=cut

######################################################################

package Class::ParamParser;
require 5.004;

# Copyright (c) 1999-2001, Darren R. Duncan. All rights reserved. This module is
# free software; you can redistribute it and/or modify it under the same terms as
# Perl itself.  However, I do request that this copyright information remain
# attached to the file.  If you modify this module and redistribute a changed
# version then please attach a note listing the modifications.

use strict;
use vars qw($VERSION);
$VERSION = '1.01';

######################################################################

=head1 DEPENDENCIES

=head2 Perl Version

	5.004 (although 5.0 may work)

=head2 Standard Modules

	I<none>

=head2 Nonstandard Modules

	I<none>

=head1 SYNOPSIS

	use Class::ParamParser;
	@ISA = qw( Class::ParamParser );

=head2 PARSING PARAMS INTO NAMED HASH

	sub textfield {
		my $self = shift( @_ );
		my $rh_params = $self->params_to_hash( \@_, 0, 
			[ 'name', 'value', 'size', 'maxlength' ], 
			{ 'default' => 'value' } );
		$rh_params->{'type'} = 'text';
		return( $self->make_html_tag( 'input', $rh_params ) );
	}

	sub textarea {
		my $self = shift( @_ );
		my $rh_params = $self->params_to_hash( \@_, 0, 
			[ 'name', 'text', 'rows', 'cols' ], { 'default' => 'text', 
			'value' => 'text', 'columns' => 'cols' }, 'text' );
		my $ra_text = delete( $rh_params->{'text'} );
		return( $self->make_html_tag( 'textarea', $rh_params, $ra_text ) );
	}

	sub AUTOLOAD {
		my $self = shift( @_ );
		my $rh_params = $self->params_to_hash( \@_, 0, 'text', {}, 'text' );
		my $ra_text = delete( $rh_params->{'text'} );
		$AUTOLOAD =~ m/([^:]*)$/;
		my $tag_name = $1;
		return( $self->make_html_tag( $tag_name, $rh_params, $ra_text ) );
	}

=head2 PARSING PARAMS INTO POSITIONAL ARRAY

	sub property {
		my $self = shift( @_ );
		my ($key,$new_value) = $self->params_to_array(\@_,1,['key','value']);
		if( defined( $new_value ) ) {
			$self->{$key} = $new_value;
		}
		return( $self->{$key} );
	}

	sub make_html_tag {
		my $self = shift( @_ );
		my ($tag_name, $rh_params, $ra_text) = 
			$self->params_to_array( \@_, 1, 
			[ 'tag', 'params', 'text' ],
			{ 'name' => 'tag', 'param' => 'params' } );
		ref($rh_params) eq 'HASH' or $rh_params = {};
		ref($ra_text) eq 'ARRAY' or $ra_text = [$ra_text];
		return( join( '', 
			"<$tag_name", 
			(map { " $_=\"$rh_params->{$_}\"" } keys %{$rh_params}),
			">",
			@{$ra_text},
			"</$tagname>",
		) );
	}

=head1 DESCRIPTION

This Perl 5 object class implements two methods which inherited classes can use
to tidy up parameter lists for their own methods and functions.  The two methods
differ in that one returns a HASH ref containing named parameters and the other
returns an ARRAY ref containing positional parameters.

Both methods can process the same kind of input parameter formats:

=over 4

=item 

I<empty list>

=item 

value

=item 

value1, value2, ...

=item 

name1 => value1, name2 => value2, ...

=item 

-name1 => value1, -name2 => value2, ...

=item 

{ -name1 => value1, name2 => value2, ... }

=item 

{ name1 => value1, -name2 => value2, ... }, valueR

=back

Those examples included single or multiple positional parameters, single or
multiple named parameters, and a HASH ref containing named parameters (with
optional "remaining" value afterwards).  That list of input variations is not
exhaustive.  Named parameters can either be prefixed with "-" or left natural.

We assume that the parameters are named when either they come as a HASH ref or
the first parameter begins with a "-".  We assume that they are positional if
there is exactly one of them.  Otherwise we are in doubt and rely on an optional
argument to the tidying method that tells us which to guess by default.

We assume that any "value" may be an array ref (aka "multiple" values under the
same name) and hence we don't do anything special with them, passing them as is.

If the source and destination are both positional, then they are identical.

=head1 SYNTAX

This class does not export any functions or methods, so you need to call them
using object notation.  This means using B<Class-E<gt>function()> for functions
and B<$object-E<gt>method()> for methods.  If you are inheriting this class for
your own modules, then that often means something like B<$self-E<gt>method()>. 
Note that this class doesn't have any properties of its own, and doesn't use the
implicitely passed class/object reference in any way.

=head1 FUNCTIONS AND METHODS

=head2 params_to_hash( SOURCE, DEF, NAMES[, RENAME[, REM]] )

=cut

######################################################################

sub params_to_hash {
	my $self = shift( @_ );
	my $ra_params_in = shift( @_ );
	my $posit_by_def = shift( @_ ) || 0;	
	my $ra_posit_names = shift( @_ ) || '';  # also single param name
	my $rh_params_to_rename = shift( @_ );
	my $remaining_param_name = shift( @_ ) || '';

	ref( $ra_params_in ) eq 'ARRAY' or $ra_params_in = [];
	ref( $rh_params_to_rename ) eq 'HASH' or $rh_params_to_rename = {};
	ref( $ra_posit_names ) eq 'ARRAY' or 
		$ra_posit_names = [$ra_posit_names];

	my $is_positional;
	if( ref( $ra_params_in->[0] ) eq 'HASH' or 
			substr( $ra_params_in->[0], 0, 1 ) eq '-' ) {
		$is_positional = 0;
	} elsif( scalar( @{$ra_params_in} ) == 1 ) {
		$is_positional = 1;
	} else {
		$is_positional = $posit_by_def;
	}
	
	my %params_out = ();
	
	if( $is_positional ) {
		foreach my $i (0..$#{$ra_params_in}) {
			$params_out{$ra_posit_names->[$i]} = $ra_params_in->[$i];
		}

	} else {
		if( ref( $ra_params_in->[0] ) eq 'HASH' ) {
			%params_out = %{$ra_params_in->[0]};
		} else {
			%params_out = @{$ra_params_in};
		}
		
		foreach my $key (keys %params_out) {
			my $value = delete( $params_out{$key} );	
			if( substr( $key, 0, 1 ) eq '-' ) {
				$key = substr( $key, 1 );
			}
			if( $rh_params_to_rename->{$key} ) {
				$key = $rh_params_to_rename->{$key};
			}
			$params_out{$key} = $value;
		}

		if( ref( $ra_params_in->[0] ) eq 'HASH' 
				and $#{$ra_params_in} > 0 ) {
			$params_out{$remaining_param_name} = $ra_params_in->[1];
		}
	}
	
	delete( $params_out{''} );

	return( \%params_out );
}

######################################################################

=head2 params_to_array( SOURCE, DEF, NAMES[, RENAME[, REM]] )

=cut

######################################################################

sub params_to_array {
	my $self = shift( @_ );
	my $ra_params_in = shift( @_ );
	my $posit_by_def = shift( @_ ) || 0;	
	my $ra_posit_names = shift( @_ ) || '';  # single param name
	my $rh_params_to_rename = shift( @_ );
	my $remaining_param_name = shift( @_ ) || '';

	ref( $ra_params_in ) eq 'ARRAY' or $ra_params_in = [];
	ref( $rh_params_to_rename ) eq 'HASH' or $rh_params_to_rename = {};
	ref( $ra_posit_names ) eq 'ARRAY' or 
		$ra_posit_names = [$ra_posit_names];

	my $is_positional;
	if( ref( $ra_params_in->[0] ) eq 'HASH' or 
			substr( $ra_params_in->[0], 0, 1 ) eq '-' ) {
		$is_positional = 0;
	} elsif( scalar( @{$ra_params_in} ) == 1 ) {
		$is_positional = 1;
	} else {
		$is_positional = $posit_by_def;
	}
	
	my @params_out = ();
	
	if( $is_positional ) {
		@params_out = @{$ra_params_in};

	} else {
		my %params_out_buf = ();
	
		if( ref( $ra_params_in->[0] ) eq 'HASH' ) {
			%params_out_buf = %{$ra_params_in->[0]};
		} else {
			%params_out_buf = @{$ra_params_in};
		}
		
		foreach my $key (keys %params_out_buf) {
			my $value = delete( $params_out_buf{$key} );	
			if( substr( $key, 0, 1 ) eq '-' ) {
				$key = substr( $key, 1 );
			}
			if( $rh_params_to_rename->{$key} ) {
				$key = $rh_params_to_rename->{$key};
			}
			$params_out_buf{$key} = $value;
		}

		if( ref( $ra_params_in->[0] ) eq 'HASH' 
				and $#{$ra_params_in} > 0 ) {
			$params_out_buf{$remaining_param_name} = $ra_params_in->[1];
		}

		delete( $params_out_buf{''} );

		foreach my $i (0..$#{$ra_posit_names}) {
			$params_out[$i] = $params_out_buf{$ra_posit_names->[$i]};
		}
	}

	return( \@params_out );
}

######################################################################

1;
__END__

=head1 ARGUMENTS

The arguments for the above methods are the same, so they are discussed together
here:

=over 4

=item 1

The first argument, SOURCE, is an ARRAY ref containing the original parameters
that were passed to the method which calls this one.  It is safe to pass "\@_"
because we don't modify the argument at all.  If SOURCE isn't a valid ARRAY ref
then its default value is [].

=item 1

The second argument, DEF, is a boolean/scalar that tells us whether, when in
doubt over whether SOURCE is in positional or named format, what to guess by
default.  A value of 0, the default, means we guess named, and a value of 1 means
we assume positional.

=item 1

The third argument, NAMES, is an ARRAY ref (or SCALAR) that provides the names to
use when SOURCE and our return value are not in the same format (named or
positional).  This is because positional parameters don't know what their names
are and named parameters (hashes) don't know what order they belong in; the NAMES
array provides the missing information to both.  The first name in NAMES matches
the first value in a positional SOURCE, and so-on.  Likewise, the order of
argument names in NAMES determines the sequence for positional output when the
SOURCE is named.

=item 1

The optional fourth argument, RENAME, is a HASH ref that allows us to interpret a
variety of names from a SOURCE in named format as being aliases for one enother. 
The keys in the hash are names to look for and the values are what to rename them
to.  Keys are matched irregardless of whether the SOURCE names have "-" in front
of them or not.  If several SOURCE names are renamed to the same hash value, then
all but one are lost; the SOURCE should never contain more than one alias for the
same parameter anyway.  One way to explicitely delete a parameter is to rename it
with "", as parameters with that name are discarded.

=item 1

The optional fifth argument, REM, is only used in circumstances where the first
element of SOURCE is a HASH ref containing the actual named parameters that
SOURCE would otherwise be.  If SOURCE has a second, "remaining" element following
the HASH ref, then REM says what its name is.  Remaining parameters with the same
name as normal parameters (post renaming and "-" substitution) take precedence. 
The default value for REM is "", and it is discarded unless renamed.

=back

=head1 AUTHOR

Copyright (c) 1999-2001, Darren R. Duncan. All rights reserved. This module is
free software; you can redistribute it and/or modify it under the same terms as
Perl itself.  However, I do request that this copyright information remain
attached to the file.  If you modify this module and redistribute a changed
version then please attach a note listing the modifications.

I am always interested in knowing how my work helps others, so if you put this
module to use in any of your own code then please send me the URL.  Also, if you
make modifications to the module because it doesn't work the way you need, please
send me a copy so that I can roll desirable changes into the main release.

Address comments, suggestions, and bug reports to B<perl@DarrenDuncan.net>.

=head1 SEE ALSO

perl(1).

=cut
