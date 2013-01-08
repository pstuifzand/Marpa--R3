#!perl
# Copyright 2012 Jeffrey Kegler
# This file is part of Marpa::R2.  Marpa::R2 is free software: you can
# redistribute it and/or modify it under the terms of the GNU Lesser
# General Public License as published by the Free Software Foundation,
# either version 3 of the License, or (at your option) any later version.
#
# Marpa::R2 is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser
# General Public License along with Marpa::R2.  If not, see
# http://www.gnu.org/licenses/.
# The example from p. 166 of Leo's paper,
# augmented to test Leo prediction items.
#

use 5.010;
use strict;
use warnings;

use Test::More tests => 7;

use lib 'inc';
use Marpa::R2::Test;
use Marpa::R2;

## no critic (Subroutines::RequireArgUnpacking)

sub main::default_action {
    shift;
    return ( join q{}, grep {defined} @_ );
}

## use critic

my $grammar = Marpa::R2::Grammar->new(
    {   start => 'S',
        rules => [
            [ 'S', [qw/a A/] ],
            [ 'A', [qw/B/] ],
            [ 'B', [qw/C/] ],
            [ 'C', [qw/S/] ],
            [ 'S', [], ],
        ],
        terminals      => [qw(a)],
        default_action => 'main::default_action',
    }
);

$grammar->precompute();

Marpa::R2::Test::is( $grammar->show_symbols(),
    <<'END_OF_STRING', 'Leo166 Symbols' );
0: a, terminal
1: S
2: A
3: B
4: C
END_OF_STRING

Marpa::R2::Test::is( $grammar->show_rules,
    <<'END_OF_STRING', 'Leo166 Rules' );
0: S -> a A
1: A -> B
2: B -> C
3: C -> S
4: S -> /* empty !used */
END_OF_STRING

Marpa::R2::Test::is( $grammar->show_AHFA, <<'END_OF_STRING', 'Leo166 AHFA' );
* S0:
S['] -> . S
 <S> => S2; leo(S['])
* S1: predict
S -> . a A
S -> . a A[]
 <a> => S3; S4
* S2: leo-c
S['] -> S .
* S3:
S -> a . A
S -> a A[] .
 <A> => S5; leo(S)
* S4: predict
S -> . a A
S -> . a A[]
A -> . B
B -> . C
C -> . S
 <B> => S7; leo(A)
 <C> => S8; leo(B)
 <S> => S6; leo(C)
 <a> => S3; S4
* S5: leo-c
S -> a A .
* S6: leo-c
C -> S .
* S7: leo-c
A -> B .
* S8: leo-c
B -> C .
END_OF_STRING

my $length = 20;

LEO_FLAG: for my $leo_flag ( 0, 1 ) {
    my $recce = Marpa::R2::Recognizer->new(
        { grammar => $grammar, leo => $leo_flag } );

    my $i                 = 0;
    my $latest_earley_set = $recce->latest_earley_set();
    my $max_size          = $recce->earley_set_size($latest_earley_set);
    TOKEN: while ( $i++ < $length ) {
        $recce->read( 'a', 'a' );
        $latest_earley_set = $recce->latest_earley_set();
        my $size = $recce->earley_set_size($latest_earley_set);

        $max_size = $size > $max_size ? $size : $max_size;
    } ## end while ( $i++ < $length )

    # Note that the length formula only works
    # beginning with Earley set c, for some small
    # constant c
    my $expected_size = $leo_flag ? 4 : ( $length - 1 ) * 4 + 3;
    Marpa::R2::Test::is( $max_size, $expected_size,
        "Leo flag $leo_flag, size $max_size" );

    my $value_ref = $recce->value();
    my $value = $value_ref ? ${$value_ref} : 'No parse';
    Marpa::R2::Test::is( $value, 'a' x $length, 'Leo p166 parse' );

} ## end for my $leo_flag ( 0, 1 )

1;    # In case used as "do" file

# Local Variables:
#   mode: cperl
#   cperl-indent-level: 4
#   fill-column: 100
# End:
# vim: expandtab shiftwidth=4:
