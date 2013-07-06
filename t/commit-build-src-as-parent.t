#!perl

use strict;
use warnings;

use Dist::Zilla  1.093250;
use Dist::Zilla::Tester;
use File::Temp qw{ tempdir };
use Git::Wrapper;
use Path::Class;
use Test::More   tests => 8;
use Try::Tiny qw(try);
use Cwd qw(cwd);

# Mock HOME to avoid ~/.gitexcludes from causing problems
$ENV{HOME} = tempdir( CLEANUP => 1 );

my $corpus_dir = dir('corpus/commit-build-src-as-parent')->absolute;

my $cwd = cwd();
END { chdir $cwd if $cwd };
my $zilla = Dist::Zilla::Tester->from_config({ dist_root => $corpus_dir, });

# build fake repository
chdir $zilla->tempdir->subdir('source');
system "git init -q";

my $git = Git::Wrapper->new('.');
$git->config( 'user.name'  => 'dzp-git test' );
$git->config( 'user.email' => 'dzp-git@test' );
$git->add( qw{ dist.ini Changes } );
$git->commit( { message => 'initial commit' } );

$zilla->build;
ok( $git->rev_parse('-q', '--verify', 'refs/heads/build/master'), 'source repo has the "build/master" branch')
    or diag $git->branch;
is( scalar $git->log('build/master'), 2, 'two commit on the build/master branch')
    or diag $git->branch;
is( scalar $git->ls_tree('build/master'), 2, 'two files in latest commit on the build/master branch')
    or diag $git->branch;

my @log = $git->log('build/master');

like try {$log[1]->message} => qr/initial commit/, 'master is a parent';
like try {$log[0]->message} => qr/Build results of \w+ \(on master\)/, 'build commit';

chdir $cwd;

my $zilla2 = Dist::Zilla::Tester->from_config({
  dist_root => dir('corpus/commit-build')->absolute,
});

# build fake repository
chdir $zilla2->tempdir->subdir('source');
system "git init -q";
my $git2 = Git::Wrapper->new('.');
$git2->config( 'user.name'  => 'dzp-git test' );
$git2->config( 'user.email' => 'dzp-git@test' );
$git2->remote('add','origin', $zilla->tempdir->subdir('source')->stringify);
$git2->fetch;
$git2->reset('--hard','origin/master');
$git2->checkout('-b', 'topic/1');
append_to_file('dist.ini', "\n");
$git2->commit('-a', '-m', 'commit on topic branch');
$zilla2->build;

ok( $git2->rev_parse('-q', '--verify', 'refs/heads/build/topic/1'), 'source repo has the "build/topic/1" branch') or diag $git2->branch;

chdir $cwd;
my $zilla3 = Dist::Zilla::Tester->from_config({
  dist_root => dir('corpus/commit-build')->absolute,
});

# build fake repository
chdir $zilla3->tempdir->subdir('source');
system "git init -q";
my $git3 = Git::Wrapper->new('.');
$git3->config( 'user.name'  => 'dzp-git test' );
$git3->config( 'user.email' => 'dzp-git@test' );
$git3->remote('add','origin', $zilla->tempdir->subdir('source')->stringify);
$git3->fetch;
$git3->branch('build/master', 'origin/build/master');
$git3->reset('--hard','origin/master');
append_to_file('dist.ini', "\n\n");
$git3->commit('-a', '-m', 'commit on master');
$zilla3->build;
is( scalar $git3->log('build/master'), 3, 'three commits on the build/master branch')
    or diag $git3->branch;
is( scalar $git->ls_tree('build/master'), 2, 'two files in latest commit on the build/master branch')
    or diag $git->branch;

sub append_to_file {
    my ($file, @lines) = @_;
    open my $fh, '>>', $file or die "can't open $file: $!";
    print $fh @lines;
    close $fh;
}
