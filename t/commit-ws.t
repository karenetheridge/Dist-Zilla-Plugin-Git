#!perl

use strict;
use warnings;

use Dist::Zilla  1.093250;
use Dist::Zilla::Tester;
use File::pushd qw(pushd);
use Git::Wrapper;
use Path::Tiny 0.012 qw(path); # cwd
use Test::More   tests => 1;

# Mock HOME to avoid ~/.gitexcludes from causing problems
my $tmpdir = Path::Tiny->tempdir( CLEANUP => 1 );
$ENV{HOME} = "$tmpdir";

my $zilla = Dist::Zilla::Tester->from_config({
  dist_root => path('corpus/commit-ws')->absolute,
});

# build fake repository
{
  my $dir = pushd(path( $zilla->tempdir )->child('source'));
  system "git init";

  my $git = Git::Wrapper->new('.');
  $git->config( 'user.name'  => 'dzp-git test' );
  $git->config( 'user.email' => 'dzp-git@test' );
  $git->add( qw{ dist.ini Changes } );
  $git->commit( { message => 'initial commit' } );

  # do a release, with changes and dist.ini updated
  append_to_file('Changes',  "\n");
  append_to_file('dist.ini', "\n");
  $zilla->release;

  # check if dist.ini and changelog have been committed
  my ($log) = $git->log( 'HEAD' );
  like( $log->message, qr/v1.23\n[^a-z]*foo[^a-z]*bar[^a-z]*baz/, 'commit message taken from changelog' );
}

sub append_to_file {
    my ($file, @lines) = @_;
    my $fh = path( $file )->opena;
    print $fh @lines;
    close $fh;
}
