# Copyright 2013 Jeffrey Kegler
# This file is part of Marpa::R3.  Marpa::R3 is free software: you can
# redistribute it and/or modify it under the terms of the GNU Lesser
# General Public License as published by the Free Software Foundation,
# either version 3 of the License, or (at your option) any later version.
#
# Marpa::R3 is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser
# General Public License along with Marpa::R3.  If not, see
# http://www.gnu.org/licenses/.

package Marpa::R3;

use 5.010;
use strict;
use warnings;

use vars qw($VERSION $STRING_VERSION @ISA $DEBUG);
$VERSION        = '3.001_000';
$STRING_VERSION = $VERSION;
## no critic (BuiltinFunctions::ProhibitStringyEval)
$VERSION = eval $VERSION;
## use critic
$DEBUG = 0;

use Carp;
use English qw( -no_match_vars );

use Marpa::R3::Version;

eval {
    require XSLoader;
    XSLoader::load( 'Marpa::R3', $Marpa::R3::STRING_VERSION );
    1;
} or eval {
    require DynaLoader;
## no critic(ClassHierarchies::ProhibitExplicitISA)
    push @ISA, 'DynaLoader';
    Dynaloader::bootstrap Marpa::R3 $Marpa::R3::STRING_VERSION;
    1;
} or Carp::croak("Could not load XS version of Marpa::R3: $EVAL_ERROR");

@Marpa::R3::CARP_NOT = ();
for my $start (qw(Marpa::R3)) {
    for my $middle ( q{}, '::Internal' ) {
        for my $end ( q{}, qw(::Scanless ::Stuifzand ::Recognizer ::Callback ::Grammar ::Value) ) {
            push @Marpa::R3::CARP_NOT, $start . $middle . $end;
        }
    }
} ## end for my $start (qw(Marpa::R3))
PACKAGE: for my $package (@Marpa::R3::CARP_NOT) {
    no strict 'refs';
    next PACKAGE if $package eq 'Marpa';
    *{ $package . q{::CARP_NOT} } = \@Marpa::R3::CARP_NOT;
}

if ( not $ENV{'MARPA_AUTHOR_TEST'} ) {
    $Marpa::R3::DEBUG = 0;
}
else {
    Marpa::R3::Thin::debug_level_set(1);
    $Marpa::R3::DEBUG = 1;
}

sub version_ok {
    my ($sub_module_version) = @_;
    return 'not defined' if not defined $sub_module_version;
    return "$sub_module_version does not match Marpa::R3::VERSION " . $VERSION
        if $sub_module_version != $VERSION;
    return;
} ## end sub version_ok

# Set up the error values
my @error_names = Marpa::R3::Thin::error_names();
for ( my $error = 0; $error <= $#error_names; ) {
    my $current_error = $error;
    (my $name = $error_names[$error] ) =~ s/\A MARPA_ERR_//xms;
    no strict 'refs';
    *{ "Marpa::R3::Error::$name" } = \$current_error;
    # This shuts up the "used only once" warning
    my $dummy = eval q{$} . 'Marpa::R3::Error::' . $name;
    $error++;
}

my $version_result;
require Marpa::R3::Internal;
( $version_result = version_ok($Marpa::R3::Internal::VERSION) )
    and die 'Marpa::R3::Internal::VERSION ', $version_result;

require Marpa::R3::Grammar;
( $version_result = version_ok($Marpa::R3::Grammar::VERSION) )
    and die 'Marpa::R3::Grammar::VERSION ', $version_result;

require Marpa::R3::Recognizer;
( $version_result = version_ok($Marpa::R3::Recognizer::VERSION) )
    and die 'Marpa::R3::Recognizer::VERSION ', $version_result;

require Marpa::R3::Value;
( $version_result = version_ok($Marpa::R3::Value::VERSION) )
    and die 'Marpa::R3::Value::VERSION ', $version_result;

require Marpa::R3::Scanless;
( $version_result = version_ok($Marpa::R3::Scanless::VERSION) )
    and die 'Marpa::R3::Scanless::VERSION ', $version_result;

require Marpa::R3::Stuifzand;
( $version_result = version_ok($Marpa::R3::Stuifzand::VERSION) )
    and die 'Marpa::R3::Stuifzand::VERSION ', $version_result;

1;
