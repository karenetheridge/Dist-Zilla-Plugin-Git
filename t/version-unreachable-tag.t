use strict;
use warnings;

use Dist::Zilla::Tester;
use Git::Wrapper;
use Path::Class;
use File::Copy::Recursive qw{ dircopy };
use File::Temp            qw{ tempdir };
use File::pushd           qw{ pushd tempd };

use Test::More 0.88 tests => 5;

# we chdir around so make @INC absolute
BEGIN { 
  @INC = map {; ref($_) ? $_ : dir($_)->absolute->stringify } @INC;
}

# Mock HOME to avoid ~/.gitexcludes from causing problems
$ENV{HOME} = tempdir( CLEANUP => 1 );

# save absolute corpus directory path
my $corpus_dir = dir('corpus/version-unreachable-tag')->absolute;

# isolate repo directory from possible git actions from bugs
my $tempd = tempd;

## shortcut for new tester object
sub _new_zilla {
    my $root = shift;
    return Dist::Zilla::Tester->from_config({
        dist_root => $corpus_dir,
    });
}

## Tests start here

my ($zilla, $version);
$zilla = _new_zilla;
# enter the temp source dir and make it a git dir
my $wd = pushd( $zilla->tempdir->subdir('source')->stringify );

system "git init";
my $git   = Git::Wrapper->new('.');
$git->config( 'user.name'  => 'dzp-git test' );
$git->config( 'user.email' => 'dzp-git@test' );
$git->add(".");
$git->commit({ message => 'import' });

# with no tags and no initialization, should get default
$zilla = _new_zilla;
$version = $zilla->version;
is( $version, "0.01", "default is 0.01" ); # set in dist.ini
$git->tag("v0.01");

# create new branch, with a commit, and a tag.
{
    $git->checkout({b=>1}, 'foo');
    open my $fh, '>', 'foo' or die;
    print $fh "foo\n";
    close $fh;
    $git->add('foo');
    $git->commit({ message => 'commit in foo branch' });
}

# release from this side branch
{
    local $ENV{V} = '1.00';
    $zilla = _new_zilla;
    is( $zilla->version, '1.00', 'foo branch released as 1.00' );
    $git->tag("v1.00");
}

# and again...
{
    $zilla = _new_zilla;
    is( $zilla->version, '1.01', 'next release in foo branch would be 1.01' );
}

# now go back to master and create a new branch...
{
    $git->checkout('master');
    $git->checkout({b=>1}, 'bar');
    open my $fh, '>', 'bar' or die;
    print $fh "bar\n";
    close $fh;
    $git->add('bar');
    $git->commit({ message => 'commit in bar branch' });
}
# release from this other side branch
{
    $zilla = _new_zilla;
    is( $zilla->version, '0.02', 'bar branch released as 0.02, NOT 1.00' );
    $git->tag("v0.02");
}

# and again...
{
    $zilla = _new_zilla;
    is( $zilla->version, '0.03', 'next release in bar branch would be 0.03' );
}


# XXX TODO: now test a conflicting tag and version. should give an exception!

use Test::Fatal;


