#!perl

use strict;
use warnings;

use Dist::Zilla     1.093250;
use Test::DZil;
use File::pushd;
use Git::Wrapper;
use Path::Tiny 0.012 qw( path );
use Test::More      tests => 5;

use t::Util;

# Mock HOME to avoid ~/.gitexcludes from causing problems
my $homedir = clean_environment;
my $cwd     = Path::Tiny->cwd();

for my $test (
  {
    name   => 'default',
    config => simple_ini('Git::GatherDir'),
    files  => [ qw(lib/DZT/Sample.pm share/tracked tracked) ],

  },
  {
    name   => 'include_dotfiles',
    config => simple_ini([ 'Git::GatherDir', { include_dotfiles => 1 } ]),
    files  => [ qw(.gitignore .tracked lib/DZT/Sample.pm share/tracked tracked) ],
  },
  {
    name   => 'include_untracked',
    min_git=> '1.5.4',
    config => simple_ini([ 'Git::GatherDir', { include_untracked => 1 } ]),
    files  => [ qw(dist.ini lib/DZT/Sample.pm  share/tracked tracked untracked) ],

  },
  {
    name   => 'include both',
    min_git=> '1.6.5.2',
    config => simple_ini([ 'Git::GatherDir',
                           { include_dotfiles => 1, include_untracked => 1 } ]),
    files  => [ qw(.gitignore .tracked .untracked dist.ini lib/DZT/Sample.pm
                   share/tracked tracked untracked) ],
  },
  {
    name   => 'exclude_filename',
    config => simple_ini([ 'Git::GatherDir', { exclude_filename => 'tracked' } ]),
    files  => [ qw(lib/DZT/Sample.pm share/tracked) ],

  },
) {
 SKIP: {
    skip_unless_git_version($test->{min_git}, 1) if $test->{min_git};

    my $tzil = Builder->from_config(
      { dist_root => $cwd->child('corpus/gatherdir')->absolute },
      {
        add_files => {
          'source/ignored'    => "This is ignored.\n",
          'source/untracked'  => "This is not tracked.\n",
          'source/tracked'    => "This is tracked.\n",
          'source/share/tracked' => "This is tracked, in a subdir.\n",
          'source/.tracked'   => "This is a tracked dotfile.\n",
          'source/.ignored'   => "This is an ignored dotfile.\n",
          'source/.untracked' => "This is an untracked dotfile.\n",
          'source/.gitignore' => "*ignore*\n",
          'source/dist.ini'   => $test->{config},
        },
      },
    );

    for my $token (pushd( path($tzil->tempdir)->child('source')->stringify )) {
      system "git init" and die "error initializing git repo";
    }
    my $git = Git::Wrapper->new( path($tzil->tempdir)->child('source')->stringify );
    $git->config( 'user.name'  => 'dzp-git test' );
    $git->config( 'user.email' => 'dzp-git@test' );

    # If core.autocrlf is true, the git add comand below may hang on
    # Windows.  This is probably a bug in Git::Wrapper, but a
    # workaround is to set autocrlf to false.  It seems to be caused
    # by these warning messages (from git version 1.8.5.2.msysgit.0):
    #   warning: LF will be replaced by CRLF in .gitignore.
    #   The file will have its original line endings in your working directory.
    #   warning: LF will be replaced by CRLF in .tracked.
    #   The file will have its original line endings in your working directory.
    #   warning: LF will be replaced by CRLF in share/tracked.
    #   The file will have its original line endings in your working directory.
    #   warning: LF will be replaced by CRLF in tracked.
    #   The file will have its original line endings in your working directory.
    $git->config( 'core.autocrlf' => 'false' );

    # check in tracked files
    # we cannot ship it in the dist, since PruneCruft plugin would trim it
    #   Don't use --force, because only -f works before git 1.5.6
    $git->add( -f => qw(lib share tracked .tracked .gitignore) );
    $git->commit( { message=>'files known to git' } );

    $tzil->build;

    is_deeply(
      [ sort map {; $_->name } @{ $tzil->files } ],
      $test->{files},
      "the right files were gathered with $test->{name}",
    );
  } # end SKIP
} # end for my $test
