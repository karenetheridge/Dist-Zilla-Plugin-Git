#! /usr/bin/perl
#
# This file is part of Dist-Zilla-Plugin-Git
#
# This software is copyright (c) 2009 by Jerome Quelin.
#
# This is free software; you can redistribute it and/or modify it under
# the same terms as the Perl 5 programming language system itself.
#
#---------------------------------------------------------------------

use strict;
use warnings;

use Test::More tests => 1;

diag(`git --version`);
ok(1);
