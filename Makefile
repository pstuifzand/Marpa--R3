# Copyright 2103 Jeffrey Kegler
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

.PHONY: dummy basic_test full_test etc_make install cpan_dist_files

dummy: 

basic_test:
	(cd cpan && ./Build test)

full_test: etc_make
	(cd cpan; \
	    ./Build realclean; \
	    perl Build.PL; \
	    ./Build; \
	    ./Build distmeta; \
	    ./Build test; \
	    ./Build disttest; \
	) 2>&1 | tee full_test.out

cpan/xs/general_pattern.xsh: cpan/xs/gp_generate.pl
	(cd cpan/xs; perl gp_generate.pl general_pattern.xsh)

install: cpan/xs/general_pattern.xsh
	test -d cpan/libmarpa_dist || mkdir cpan/libmarpa_dist
	test -d cpan/libmarpa_doc_dist || mkdir cpan/libmarpa_doc_dist
	(cd cpan && sh c_to_dist.sh)
	(cd cpan && perl Build.PL)
	(cd cpan && ./Build distmeta)
	(cd cpan && ./Build code)

fullinstall: install
	-mkdir cpan/libmarpa/test/dev/m4
	(cd cpan/libmarpa/test/dev && autoreconf -ivf)
	-mkdir cpan/libmarpa/test/work
	(cd cpan/libmarpa/test/work && sh ../dev/configure)
	(cd cpan/libmarpa/test/work && make)
