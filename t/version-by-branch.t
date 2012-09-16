use strict;
use warnings;

use Test::DZil qw(Builder dist_ini);
use Git::Wrapper;
use Path::Class;
use File::pushd qw(pushd tempd);
use version 0.80 ();

use Test::More 0.88;            # done_testing

# we chdir around so make @INC absolute
BEGIN {
  @INC = map {; ref($_) ? $_ : dir($_)->absolute->stringify } @INC;
}

# Make a new directory so we don't affect the source repo:

my $base_dir_pushed = tempd;
my $base_dir = dir($base_dir_pushed)->absolute;

# Mock HOME to avoid ~/.gitexcludes from causing problems:

mkdir($ENV{HOME} = $base_dir->subdir('home')->stringify);

# Create the test repo:

my $git;
my $git_dir = $base_dir->subdir('repo');
mkdir $git_dir;

sub append_file
{
  my ($fn, $data) = @_;

  my $out = $git_dir->file($fn)->open('>>') or die;
  print $out $data;

  $git->add($fn) if $git;
} # end append_file

append_file('dist.ini' => dist_ini(
  {qw(
    name              Foo
    author            foobar
    license           Perl_5
    abstract          Test-Library
    copyright_holder  foobar
    copyright_year    2009
  )},
  [ 'Git::NextVersion', { version_by_branch => 1 } ],
));

append_file(Changes => "Just getting started");

{
  my $pushd = pushd($git_dir);
  system "git init --quiet" and die "Can't initialize repo";

  $git = Git::Wrapper->new($git_dir);

  my ($version) = $git->version =~ m[^( \d+ \. \d[.\d]+ )]x;
  if ( version->parse( $version ) < version->parse('1.6.1') ) {
    plan skip_all => "git 1.6.1 or later required, you have $version";
  } else {
    plan tests => 14;
  }

  $git->config( 'user.name'  => 'dzp-git test' );
  $git->config( 'user.email' => 'dzp-git@test' );
}

#---------------------------------------------------------------------
## shortcut for new tester object

my $zilla;

sub _new_zilla {
  $zilla = Builder->from_config({ dist_root => $git_dir });
}

sub _zilla_version {
  _new_zilla;
  # Need to be in the right directory:
  my $pushd = pushd($zilla->root);
  my $version = $zilla->version;
  return $version;
}


# with no tags and no initialization, should get default
is( _zilla_version, "0.001", "works with no commits" );

$git->add(".");
$git->commit({ message => 'import' });

# with no tags and no initialization, should get default
is( _zilla_version, "0.001", "default is 0.001" );

# initialize it using V=
{
    local $ENV{V} = "1.23";
    is( _zilla_version, "1.23", "initialized with \$ENV{V}" );
}

# add a tag that doesn't match the regex
$git->tag("revert-me-later");
ok( (grep { /revert-me-later/ } $git->tag), "wrote revert-me-later tag" );

is( _zilla_version, "0.001", "default is 0.001" );

# tag 1.2.3
append_file(Changes => "1.2.3 now\n");
$git->commit({ message => 'committing 1.2.3'});
$git->tag("v1.2.3");
ok( (grep { /v1\.2\.3/ } $git->tag), "wrote v1.2.3 tag" );

is( _zilla_version, "1.2.4", "initialized from last tag" );

# make a dev branch
$git->checkout(qw(-b dev));

# tag first dev release 1.3.0
append_file(Changes => "1.3.0 dev release\n");
$git->commit({ message => 'committing 1.3.0'});
$git->tag("v1.3.0");
ok( (grep { /v1\.3\.0/ } $git->tag), "wrote v1.3.0 tag" );

is( _zilla_version, "1.3.1", "initialized from 1.3.0 tag" );

# go back to master branch
$git->checkout(qw(master));

is( _zilla_version, "1.2.4", "initialized from 1.2.3 tag on master" );

# tag stable 1.2.4
append_file(Changes => "1.2.4 stable release\n");
$git->commit({ message => 'committing 1.2.4 on master'});
$git->tag("v1.2.4");
ok( (grep { /v1\.2\.4/ } $git->tag), "wrote v1.2.4 tag" );

is( _zilla_version, "1.2.5", "initialized from 1.2.4 tag" );

# go back to dev branch
$git->checkout(qw(dev));

append_file(Changes => "1.3.1 in progress\n");
$git->commit({ message => 'committing 1.3.1 change'});

is( _zilla_version, "1.3.1", "using dev branch 1.3.0 tag" );

# go back to master branch
$git->checkout(qw(master));

append_file(Changes => "1.2.5 still in progress\n");
$git->commit({ message => 'committing 1.2.5 change'});

is( _zilla_version, "1.2.5", "using master branch 1.2.4 tag" );

# $base_dir_pushed->preserve;  print "Files in $git_dir\n";

done_testing;
