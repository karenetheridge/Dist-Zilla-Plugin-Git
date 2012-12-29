#---------------------------------------------------------------------
package t::Util;
#
# Copyright 2012 Christopher J. Madsen
#
# Author: Christopher J. Madsen <perl@cjmweb.net>
# Created:  6 Oct 2012
#
# This program is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See either the
# GNU General Public License or the Artistic License for more details.
#
# ABSTRACT: Utilities for testing Dist-Zilla-Plugin-Git
#---------------------------------------------------------------------

use 5.010;
use strict;
use warnings;

use File::Copy::Recursive qw(dircopy);
use File::pushd qw(pushd tempd);
use Git::Wrapper ();
use Path::Class;
use Test::DZil qw(Builder);
use Test::More;
use version 0.80 ();

our ($base_dir, $base_dir_pushed, $dist_dir, $git_dir, $git, $zilla);

use Exporter ();
our @ISA    = qw(Exporter);
our @EXPORT = qw($base_dir $git_dir $git $zilla
                 append_and_add append_to_file init_test keep_tempdir
                 new_zilla_from_repo
                 skip_unless_git_version slurp_text_file
                 zilla_log_is);
our @EXPORT_OK = qw($dist_dir zilla_version);

# we chdir around so make @INC absolute
BEGIN {
  @INC = map {; ref($_) ? $_ : dir($_)->absolute->stringify } @INC;
}

#=====================================================================
sub append_and_add
{
  my $fn = $_[0];

  &append_to_file;

  $git->add($fn);
} # end append_and_add

#---------------------------------------------------------------------
sub append_to_file {
  my $file = shift;

  my $fh = $git_dir->file($file)->open('>>:raw:utf8')
      or die "can't open $file: $!";

  print $fh @_;
  close $fh;
}

#---------------------------------------------------------------------
sub init_test
{
  my %opt = @_;

  $dist_dir = dir('.')->absolute; # root of the distribution

  # Make a new directory so we don't affect the source repo:
  $base_dir_pushed = tempd;
  $base_dir = dir($base_dir_pushed)->absolute;

  # Mock HOME to keep user's global Git config from causing problems:
  mkdir($ENV{HOME} = $base_dir->subdir('home')->stringify)
      or die "Failed to create $ENV{HOME}: $!";

  delete $ENV{V}; # In case we're being released with a manual version

  # Create the test repo:
  $git_dir = $base_dir->subdir('repo');
  $git_dir->mkpath;

  dircopy($dist_dir->subdir(corpus => $opt{corpus}), $git_dir)
      if defined $opt{corpus};

  if (my $files = $opt{add_files}) {
    while (my ($name, $content) = each %$files) {
      my $fn = $git_dir->file($name);
      $fn->dir->mkpath;
      open my $fh, '>:raw:utf8', $fn or die "Can't open $fn: $!";
      print { $fh } $content;
      close $fh;
    }
  } # end if add_files

  my $pushd = pushd($git_dir);
  system "git init --quiet" and die "Can't initialize repo";

  $git = Git::Wrapper->new($git_dir);

  $git->config( 'push.default' => 'matching' ); # compatibility with Git 1.8
  $git->config( 'user.name'  => 'dzp-git test' );
  $git->config( 'user.email' => 'dzp-git@test' );
} # end init_test

#---------------------------------------------------------------------
sub keep_tempdir
{
  $base_dir_pushed->preserve;
  print "Git files are in $git_dir\n";
} # end keep_tempdir

#---------------------------------------------------------------------
sub new_zilla_from_repo
{
  $zilla = Builder->from_config({dist_root => $git_dir}, @_);
} # end zilla_from_repo

#---------------------------------------------------------------------
sub skip_unless_git_version
{
  my $need_version = shift;

  my ($version) = Git::Wrapper->new('.')->version =~ m[^( \d+ \. \d[.\d]+ )]x;
  if ( version->parse( $version ) < version->parse($need_version) ) {
    plan skip_all => "git $need_version or later required, you have $version";
  }
} # end skip_unless_git_version

#---------------------------------------------------------------------
sub slurp_text_file
{
  my ($filename) = @_;

  return scalar do {
    local $/;
    if (open my $fh, '<:utf8', $zilla->tempdir->file($filename)) {
      <$fh>;
    } else {
      diag("Unable to open $filename: $!");
      undef;
    }
  };
} # end slurp_text_file

#---------------------------------------------------------------------
sub zilla_log_is
{
  my ($matching, $expected, $name) = @_;

  $name //= "log messages for $matching";

  $matching = qr /^\Q[$matching]\E/ unless ref $matching;

  my $got = join("\n", grep { /$matching/ } @{ $zilla->log_messages });
  $got =~ s/\s*\z/\n/;

  local $Test::Builder::Level = $Test::Builder::Level + 1;
  is( $got, $expected, $name);

  $zilla->clear_log_events;
}

#---------------------------------------------------------------------
sub zilla_version
{
  my $pushd = pushd($zilla->root); # Must be in the correct directory
  my $version = $zilla->version;
  return $version;
} # end zilla_version

#=====================================================================
# Package Return Value:

1;

__END__
