#!perl

use strict;
use warnings;

use Dist::Zilla  1.093250;
use Dist::Zilla::Tester;
use Git::Wrapper;
use Path::Tiny qw( path );
use Test::More   tests => 6;

# Mock HOME to avoid ~/.gitexcludes from causing problems
my $tempdir = Path::Tiny->tempdir( CLEANUP => 1 );
$ENV{HOME} = "$tempdir";

my $cwd = path('.')->absolute;
END { chdir $cwd if $cwd }
my $zilla = Dist::Zilla::Tester->from_config({
  dist_root => path('corpus/commit-build')->absolute,
});

# build fake repository
chdir path( $zilla->tempdir )->child('source');
system "git init -q";

my $git = Git::Wrapper->new('.');
$git->config( 'user.name'  => 'dzp-git test' );
$git->config( 'user.email' => 'dzp-git@test' );
$git->add( qw{ dist.ini Changes } );
$git->commit( { message => 'initial commit' } );

$zilla->build;
ok( $git->rev_parse('-q', '--verify', 'refs/heads/build/master'), 'source repo has the "build/master" branch')
    or diag $git->branch;
is( scalar $git->log('build/master'), 1, 'one commit on the build/master branch')
    or diag $git->branch;
is( scalar $git->ls_tree('build/master'), 2, 'two files in latest commit on the build/master branch')
    or diag $git->branch;

chdir $cwd;

my $zilla2 = Dist::Zilla::Tester->from_config({
  dist_root => path('corpus/commit-build')->absolute,
});

# build fake repository
chdir path( $zilla2->tempdir )->child('source');
system "git init -q";
my $git2 = Git::Wrapper->new('.');
$git2->config( 'user.name'  => 'dzp-git test' );
$git2->config( 'user.email' => 'dzp-git@test' );
$git2->remote('add','origin', path( $zilla->tempdir )->child('source')->stringify);
$git2->fetch;
$git2->reset('--hard','origin/master');
$git2->checkout('-b', 'topic/1');
append_to_file('dist.ini', "\n");
$git2->commit('-a', '-m', 'commit on topic branch');
$zilla2->build;

ok( $git2->rev_parse('-q', '--verify', 'refs/heads/build/topic/1'), 'source repo has the "build/topic/1" branch') or diag $git2->branch;

chdir $cwd;
my $zilla3 = Dist::Zilla::Tester->from_config({
  dist_root => path('corpus/commit-build')->absolute,
});

# build fake repository
chdir path($zilla3->tempdir)->child('source');
system "git init -q";
my $git3 = Git::Wrapper->new('.');
$git3->config( 'user.name'  => 'dzp-git test' );
$git3->config( 'user.email' => 'dzp-git@test' );
$git3->remote('add','origin', path($zilla->tempdir)->child('source')->stringify);
$git3->fetch;
$git3->branch('build/master', 'origin/build/master');
$git3->reset('--hard','origin/master');
append_to_file('dist.ini', "\n\n");
$git3->commit('-a', '-m', 'commit on master');
$zilla3->build;
is( scalar $git3->log('build/master'), 2, 'two commits on the build/master branch')
    or diag $git3->branch;
is( scalar $git->ls_tree('build/master'), 2, 'two files in latest commit on the build/master branch')
    or diag $git->branch;

sub append_to_file {
    my ($file, @lines) = @_;
    my $fh = path($file)->opena;
    print $fh @lines;
    close $fh;
}
