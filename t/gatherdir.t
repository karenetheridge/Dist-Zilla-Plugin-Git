#!perl
#
# This file is part of Dist-Zilla-Plugin-Git
#
# This software is copyright (c) 2009 by Jerome Quelin.
#
# This is free software; you can redistribute it and/or modify it under
# the same terms as the Perl 5 programming language system itself.
#

use strict;
use warnings;

use Dist::Zilla     1.093250;
use Test::DZil;
use File::pushd;
use File::Temp qw{ tempdir };
use Git::Wrapper;
use Path::Class;
use Test::More      tests => 4;
use Test::Exception;

# Mock HOME to avoid ~/.gitexcludes from causing problems
$ENV{HOME} = tempdir( CLEANUP => 1 );

for my $test (
  {
    config => simple_ini('Git::GatherDir'),
    files  => [ qw(lib/DZT/Sample.pm tracked) ],

  },
  {
    config => simple_ini([ 'Git::GatherDir', { include_dotfiles => 1 } ]),
    files  => [ qw(.gitignore .tracked lib/DZT/Sample.pm tracked) ],
  },
  {
    config => simple_ini([ 'Git::GatherDir', { include_untracked => 1 } ]),
    files  => [ qw(dist.ini lib/DZT/Sample.pm tracked untracked) ],

  },
  {
    config => simple_ini([ 'Git::GatherDir',
                           { include_dotfiles => 1, include_untracked => 1 } ]),
    files  => [ qw(.gitignore .tracked .untracked dist.ini lib/DZT/Sample.pm
                   tracked untracked) ],
  },
) {
  my $tzil = Builder->from_config(
    { dist_root => dir('corpus/gatherdir')->absolute },
    {
      add_files => {
        'source/ignored'    => "This is ignored.\n",
        'source/untracked'  => "This is not tracked.\n",
        'source/tracked'    => "This is tracked.\n",
        'source/.tracked'   => "This is a tracked dotfile.\n",
        'source/.ignored'   => "This is an ignored dotfile.\n",
        'source/.untracked' => "This is an untracked dotfile.\n",
        'source/.gitignore' => "*ignore*\n",
        'source/dist.ini'   => $test->{config},
      },
    },
  );

  for my $token (pushd( $tzil->tempdir->subdir('source') )) {
    system "git init" and die "error initializing git repo";
  }

  my $git = Git::Wrapper->new( $tzil->tempdir->subdir('source') );
  $git->config( 'user.name'  => 'dzp-git test' );
  $git->config( 'user.email' => 'dzp-git@test' );

  # check in dotfiles
  # we cannot ship it in the dist, since PruneCruft plugin would trim it
  #   Don't use --force, because only -f works before git 1.5.6
  $git->add( -f => qw(lib tracked .tracked .gitignore) );
  $git->commit( { message=>'ignore file for git' } );

  $tzil->build;

  is_deeply(
    [ sort map {; $_->name } @{ $tzil->files } ],
    $test->{files},
    "the right files were gathered",
  );
}
