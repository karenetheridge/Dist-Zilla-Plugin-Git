#!perl

use strict;
use warnings;

use Dist::Zilla  1.093250;
use Dist::Zilla::Tester;
use File::pushd qw(pushd);
use Git::Wrapper;
use Path::Tiny 0.012 qw( path ); # cwd
use Test::More   tests => 4;

# Mock HOME to avoid ~/.gitexcludes from causing problems
my $tempdir = Path::Tiny->tempdir( CLEANUP => 1 );
$ENV{HOME} = "$tempdir";

# build fake repository
my $zilla = Dist::Zilla::Tester->from_config({
  dist_root => path('corpus/tag')->absolute,
});

{
  my $dir = pushd(path($zilla->tempdir)->child('source'));
  system "git init";
  my $git = Git::Wrapper->new('.');

  $git->config( 'user.name'  => 'dzp-git test' );
  $git->config( 'user.email' => 'dzp-git@test' );
  $git->add( qw{ dist.ini Changes } );
  $git->commit( { message => 'initial commit' } );

  # do the release
  $zilla->release;

  # check if tag has been correctly created
  my @tags = $git->tag;
  is( scalar(@tags), 1, 'one tag created' );
  is( $tags[0], 'v1.23', 'new tag created after new version' );
  is( $tags[0], $zilla->plugin_named('Git::Tag')->tag(), 'new tag matches the tag the plugin claims is the tag.');

  # attempting to release again should fail
  eval { $zilla->release };

  like($@, qr/tag v1\.23 already exists/, 'prohibit duplicate tag');
}
