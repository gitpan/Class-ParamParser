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
$VERSION = '1.03';

######################################################################

=head1 DEPENDENCIES

=head2 Perl Version

	5.004

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
			'value' => 'text', 'columns' => 'cols' }, 'text', 1 );
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

-name1 => value1, -NAME2 => value2, ...

=item 

{ -Name1 => value1, NAME2 => value2, ... }

=item 

{ name1 => value1, -Name2 => value2, ... }, valueR

=item 

{ name1 => value1, -Name2 => value2, ... }, valueR1, valueR2, ...

=back

Those examples included single or multiple positional parameters, single or
multiple named parameters, and a HASH ref containing named parameters (with
optional "remaining" values afterwards).  That list of input variations is not
exhaustive.  Named parameters can either be prefixed with "-" or left natural.

We assume that the parameters are named when either they come as a HASH ref or
the first parameter begins with a "-".  We assume that they are positional if
there is an odd number of them.  Otherwise we are in doubt and rely on an
optional argument to the tidying method that tells us which to guess by default.

We assume that any "value" may be an array ref (aka "multiple" values under the
same name) and hence we don't do anything special with them, passing them as is.  
The only exception to this is with "remaining" values; if there is more than one 
of them and the first isn't an array ref, then they are all put in an array ref.

If the source and destination are both positional, then they are identical.

=head1 SYNTAX

This class does not export any functions or methods, so you need to call them
using object notation.  This means using B<Class-E<gt>function()> for functions
and B<$object-E<gt>method()> for methods.  If you are inheriting this class for
your own modules, then that often means something like B<$self-E<gt>method()>. 
Note that this class doesn't have any properties of its own.

=head1 FUNCTIONS AND METHODS

=head2 params_to_hash( SOURCE, DEF, NAMES[, RENAME[, REM[, LC]]] )

See below for argument descriptions.

=cut

######################################################################

sub params_to_hash {
	my $self = shift( @_ );
	return( $self->params_to_hash_or_array( 0, @_ ) );
}

######################################################################

=head2 params_to_array( SOURCE, DEF, NAMES[, RENAME[, REM[, LC]]] )

See below for argument descriptions.

=cut

######################################################################

sub params_to_array {
	my $self = shift( @_ );
	return( $self->params_to_hash_or_array( 1, @_ ) );
}

######################################################################

=head2 params_to_hash_or_array( TO, SOURCE, DEF, NAMES[, RENAME[, REM[, LC]]] )

This bonus third method is used internally to implement the first two.  It has 
an extra first argument, TO, which causes an Array ref to be returned when true 
and a Hash ref to be returned when false; the default value is false.

=cut

######################################################################

sub params_to_hash_or_array {
	my $self = shift( @_ );
	my $going_to_array = shift( @_ ) || 0;  # true means going to hash
	
	# Fetch our arguments
	
	my $ra_params_in = shift( @_ );  # also called "source"
	my $posit_by_def = shift( @_ ) || 0;	
	my $ra_posit_names = shift( @_ ) || [];  # also single param name
	my $rh_params_to_rename = shift( @_ );
	my $remaining_param_name = shift( @_ ) || '';  # follows literal hash
	my $lowercase_names = shift( @_ ) || 0;  # force param names into lowercase

	# Make sure our arguments are in the right format

	ref( $ra_params_in ) eq 'ARRAY' or $ra_params_in = [];
	ref( $ra_posit_names ) eq 'ARRAY' or $ra_posit_names = [$ra_posit_names];
	ref( $rh_params_to_rename ) eq 'HASH' or $rh_params_to_rename = {};

	# Shortcut - if our source is empty, so is our output
	
	unless( @{$ra_params_in} ) {
		return( $going_to_array ? [] : {} );
	}

	# Determine if source parameters are in positional or named format

	my $is_positional;
	if( ref( $ra_params_in->[0] ) eq 'HASH' or 
			substr( $ra_params_in->[0], 0, 1 ) eq '-' ) {
		$is_positional = 0;        # literal hash or first param starts with "-"
	} elsif( @{$ra_params_in} % 2 ) {
		$is_positional = 1;        # odd number of parameters
	} else {
		$is_positional = $posit_by_def;  # even num of params, no "-" on first
	}
	
	# Declare the destination variables we will output
	
	my %params_out = ();
	my @params_out = ();
	
	# If source is positional, then no need to worry about improper names
	
	if( $is_positional ) {

		# Output = Input when both are positional

		if( $going_to_array ) {
			@params_out = @{$ra_params_in};

		# Do a mapped conversion from positional to named format

		} else {
			foreach my $i (0..$#{$ra_params_in}) {
				$params_out{$ra_posit_names->[$i]} = $ra_params_in->[$i];
			}
		}

	# If source is named, we need to make sure names are correct

	} else {

		# Fetch named parameter list from wherever it is

		if( ref( $ra_params_in->[0] ) eq 'HASH' ) {
			%params_out = %{$ra_params_in->[0]};  # first param as literal hash
		} else {
			%params_out = @{$ra_params_in};       # or whole param list
		}
		
		# Coerce parameter names into correct format and resolve aliases

		foreach my $key (sort keys %params_out) {
			my $value = delete( $params_out{$key} );	
			if( substr( $key, 0, 1 ) eq '-' ) {
				$key = substr( $key, 1 );             # remove any leading "-"
			}
			$lowercase_names and $key = lc( $key );   # change to lowercase
			if( exists( $rh_params_to_rename->{$key} ) ) {
				$key = $rh_params_to_rename->{$key};  # change to favorite alias 
			}
			$params_out{$key} = $value;
		}

		# Look for any "remaining" parameter and include it in output

		if( ref( $ra_params_in->[0] ) eq 'HASH' 
				and $#{$ra_params_in} > 0 ) {

			# If exactly one "remaining", or first is array ref, return it as is

			if( ref( $ra_params_in->[1] ) eq 'ARRAY' 
					or $#{$ra_params_in} == 1 ) {
				$params_out{$remaining_param_name} = $ra_params_in->[1];

			# If multiple "remaining" and first not an array, return all in array

			} else {
				$params_out{$remaining_param_name} = 
					[@{$ra_params_in}[1..$#{$ra_params_in}]];
			}
		}

		# Do a mapped conversion from named to positional format

		if( $going_to_array ) {
			foreach my $i (0..$#{$ra_posit_names}) {
				$params_out[$i] = $params_out{$ra_posit_names->[$i]};
			}
		}
	}
	
	# Remove unwanted parameters from output list
	
	delete( $params_out{''} );

	# Return parsed params in appropriate variable type

	return( $going_to_array ? \@params_out : \%params_out );
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
to.  Keys are matched regardless of whether the SOURCE names have "-" in front
of them or not.  If several SOURCE names are renamed to the same hash value, then
all but one are lost; the SOURCE should never contain more than one alias for the
same parameter anyway.  One way to explicitely delete a parameter is to rename it
with "", as parameters with that name are discarded.

=item 1

The optional fifth argument, REM, is only used in circumstances where the first
element of SOURCE is a HASH ref containing the actual named parameters that
SOURCE would otherwise be.  If SOURCE has extra, "remaining" elements following
the HASH ref, then REM says what its name is.  Remaining parameters with the same
name as normal parameters (post renaming and "-" substitution) take precedence. 
The default value for REM is "", and it is discarded unless renamed.  Note that 
the value returned with REM can be either a single scalar value, when the 
"remaining" is a single scalar value, or an array ref, when there are more than 
one "remaining" or the first "remaining" is an array ref (passed as is).

=item 1

The optional sixth argument, LC, is a boolean/scalar that forces named parameters 
in SOURCE to be lowercased; by default this is false, meaning that the original 
case is preserved.  Use this when you want your named parameters to have 
case-insensitive names, for accurate matching by your own code or RENAME.  If you 
use this, you must provide lowercased keys and values in your RENAME hash, as 
well as lowercased NAMES and REM; none of these are lowercased for you.

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
