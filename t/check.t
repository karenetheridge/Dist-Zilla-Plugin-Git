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
use Test::DZil qw{ Builder simple_ini };
use File::Temp qw{ tempdir };
use File::pushd qw{ pushd };
use Git::Wrapper;
use Test::More 0.88 tests => 11; # done_testing
use Test::Exception;

# Mock HOME to avoid ~/.gitexcludes from causing problems
$ENV{HOME} = tempdir( CLEANUP => 1 );

my ($zilla, $git, $pushd);

sub new_tzil
{
  undef $pushd;             # Restore original directory, if necessary

  # build fake repository
  $zilla = Builder->from_config(
    { dist_root => 'corpus/check' },
    {
      add_files => {
        'source/dist.ini' => simple_ini(
          [ 'Git::Check' => { @_ } ],
          'FakeRelease',
        ),
        'source/.gitignore' => "DZT-Sample-*\n",
      },
    },
  );

  $pushd = pushd($zilla->tempdir->subdir('source'));
  print "# ";                   # Comment output of git init
  system "git init";
  $git   = Git::Wrapper->new('.');
  $git->config( 'user.name'  => 'dzp-git test' );
  $git->config( 'user.email' => 'dzp-git@test' );

  # create initial commit
  #   Don't use --force, because only -f works before git 1.5.6
  $git->add( -f => '.gitignore');
  $git->commit( { message=>'ignore file for git' } );
} # end new_tzil

#---------------------------------------------------------------------
# Test with default config:

new_tzil();

# untracked files
throws_ok { $zilla->release } qr/untracked files/, 'untracked files';

# index not clean
$git->add( qw{ dist.ini Changes foobar } );
throws_ok { $zilla->release } qr/some changes staged/, 'index not clean';
$git->commit( { message => 'initial commit' } );

# modified files
append_to_file('foobar', 'Foo-*');
throws_ok { $zilla->release } qr/uncommitted files/, 'uncommitted files';
$git->checkout( 'foobar' );

# changelog and dist.ini can be modified
append_to_file('Changes',  "\n");
append_to_file('dist.ini', "\n");
lives_ok { $zilla->release } 'Changes and dist.ini can be modified';

# ensure dist.ini does not match dist_ini
append_to_file('dist_ini', 'Hello');
$git->add( qw{ dist_ini } );
$git->commit( { message => 'add dist_ini' } );
append_to_file('dist_ini', 'World');
throws_ok { $zilla->release } qr/uncommitted files/,
    'dist_ini must not be modified';

#---------------------------------------------------------------------
# Test with no dirty files allowed at all:

new_tzil(allow_dirty => '');

# untracked files
throws_ok { $zilla->release } qr/untracked files/,
    'untracked files with allow_dirty = ""';

# index not clean
$git->add( qw{ dist.ini Changes foobar } );
throws_ok { $zilla->release } qr/some changes staged/,
    'index not clean with allow_dirty = ""';
$git->commit( { message => 'initial commit' } );

# modified files
append_to_file('foobar', 'Foo-*');
throws_ok { $zilla->release } qr/uncommitted files/,
    'uncommitted files with allow_dirty = ""';
$git->checkout( 'foobar' );

# changelog cannot be modified
append_to_file('Changes', "\n");
throws_ok { $zilla->release } qr/uncommitted files/,
    'Changes must not be modified';
$git->checkout( 'Changes' );

# dist.ini cannot be modified
append_to_file('dist.ini', "\n");
throws_ok { $zilla->release } qr/uncommitted files/,
    'dist.ini must not be modified';
$git->checkout( 'dist.ini' );

lives_ok { $zilla->release } 'Changes and dist.ini are unmodified';

#---------------------------------------------------------------------
sub append_to_file {
    my ($file, @lines) = @_;
    open my $fh, '>>', $file or die "can't open $file: $!";
    print $fh @lines;
    close $fh;
}

done_testing;
