package Dist::Zilla::Plugin::Git::GatherDir;
# ABSTRACT: gather all tracked files in a Git working directory
use Moose;
use Moose::Autobox;
use MooseX::Types::Path::Class qw(Dir File);
with 'Dist::Zilla::Role::Git::Repo';
use Dist::Zilla::Plugin::GatherDir 4.200016 (); # exclude_match
extends 'Dist::Zilla::Plugin::GatherDir';

=head1 DESCRIPTION

This is a trivial variant of the L<GatherDir|Dist::Zilla::Plugin::GatherDir>
plugin.  It looks in the directory named in the L</root> attribute and adds all
the Git tracked files it finds there (as determined by C<git ls-files>).  If the
root begins with a tilde, the tilde is replaced with the current user's home
directory according to L<File::HomeDir>.

Most users just need:

  [Git::GatherDir]

...and this will pick up all tracked files from the current directory into the
dist.  You can use it multiple times, as you can any other plugin, by providing
a plugin name.  For example, if you want to include external specification
files into a subdir of your dist, you might write:

  [Git::GatherDir]
  ; this plugin needs no config and gathers most of your files

  [Git::GatherDir / SpecFiles]
  ; this plugin gets all tracked files in the root dir and adds them under ./spec
  root   = ~/projects/my-project/spec
  prefix = spec

=cut

use File::Spec;
use List::AllUtils qw(uniq);
use Path::Class;

use namespace::autoclean;

=attr root

This is the directory in which to look for files.  If not given, it defaults to
the dist root -- generally, the place where your F<dist.ini> or other
configuration file is located.

=attr prefix

This parameter can be set to gather all the files found under a common
directory.  See the L<description|DESCRIPTION> above for an example.

=attr include_dotfiles

By default, files will not be included if they begin with a dot.  This goes
both for files and for directories relative to the C<root>.

In almost all cases, the default value (false) is correct.

=attr include_untracked

By default, files not tracked by Git will not be gathered.  If this is
set to a true value, then untracked files not covered by a Git ignore
pattern (i.e. those reported by C<git ls-files -o --exclude-standard>)
are also gathered (and you'll probably want to use
L<Git::Check|Dist::Zilla::Plugin::Git::Check> to ensure all files are
checked in before a release).

C<include_untracked> requires at least Git 1.5.4, but you should
probably not use it if your Git is older than 1.6.5.2.  Versions
before that would not list files matched by your F<.gitignore>, even
if they were already being tracked by Git (which means they will not
be gathered, even though they should be).  Whether that is a problem
depends on the contents of your exclude files (including the global
one, if any).

=attr follow_symlinks

Git::GatherDir does not honor GatherDir's
L<follow_symlinks|Dist::Zilla::Plugin::GatherDir/follow_symlinks>
option.  While the attribute exists (because Git::GatherDir is a
subclass), setting it has no effect.

Directories that are symlinks will not be gathered.  Instead, you'll
get a message saying C<WARNING: %s is symlink to directory, skipping it>.
To suppress the warning, add that directory to C<exclude_filename> or
C<exclude_match>.  To gather the files in the symlinked directory, use
a second instance of GatherDir or Git::GatherDir with appropriate
C<root> and C<prefix> options.

Files which are symlinks are always gathered.

=attr exclude_filename

To exclude certain files from being gathered, use the C<exclude_filename>
option. This may be used multiple times to specify multiple files to exclude.

=attr exclude_match

This is just like C<exclude_filename> but provides a regular expression
pattern.  Files matching the pattern are not gathered.  This may be used
multiple times to specify multiple patterns to exclude.

=cut

has include_untracked => (
  is  => 'ro',
  isa => 'Bool',
  default => 0,
);

override gather_files => sub {
  my ($self) = @_;

  require Git::Wrapper;

  my $root = "" . $self->root;
  $root =~ s{^~([\\/])}{require File::HomeDir; File::HomeDir->my_home . $1}e;
  $root = Path::Class::dir($root);

  my $git = Git::Wrapper->new("$root");

  my @opts;
  @opts = qw(--cached --others --exclude-standard) if $self->include_untracked;

  my $exclude_regex = qr/\000/;
  $exclude_regex = qr/$exclude_regex|$_/
    for ($self->exclude_match->flatten);

  my %is_excluded = map {; $_ => 1 } $self->exclude_filename->flatten;

  my @files;
  FILE: for my $filename (uniq $git->ls_files(@opts)) {
    my $file = file($filename)->relative($root);

    unless ($self->include_dotfiles) {
      next FILE if $file->basename =~ qr/^\./;
      next FILE if grep { /^\.[^.]/ } $file->dir->dir_list;
    }

    next if $file =~ $exclude_regex;
    next if $is_excluded{ $file };

    if (-d $file) {
      $self->log("WARNING: $file is symlink to directory, skipping it");
      next;
    }

    push @files, $self->_file_from_filename($filename);
  }

  for my $file (@files) {
    (my $newname = $file->name) =~ s{\A\Q$root\E[\\/]}{}g;
    $newname = File::Spec->catdir($self->prefix, $newname) if $self->prefix;
    $newname = Path::Class::dir($newname)->as_foreign('Unix')->stringify;

    $file->name($newname);
    $self->add_file($file);
  }

  return;
};


__PACKAGE__->meta->make_immutable;
no Moose;
1;

=for Pod::Coverage
    gather_dir
    gather_files

