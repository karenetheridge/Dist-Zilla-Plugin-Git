##{
BEGIN {
  die "You must process this file through ModuleBuild::Custom by running dzil\n"
    unless defined Dist::Zilla::Plugin::ModuleBuild::Custom->VERSION;
} ''
##}
use strict;
use warnings;

use Module::Build 0.3601;
use version 0.80 ();

my %module_build_args = (
##{ $plugin->get_default(qw(dist_abstract dist_author dist_name dist_version
                            license module_name recursive_test_files
                            script_files share_dir)) ##}
##{ $plugin->get_prereqs(1) ##}
  get_options => { 'force-install' => undef },
);

unless ( eval { Module::Build->VERSION(0.4004) } ) {
  my $tr = delete $module_build_args{test_requires};
  my $br = $module_build_args{build_requires};
  for my $mod ( keys %$tr ) {
    if ( exists $br->{$mod} ) {
      $br->{$mod} = $tr->{$mod} if $tr->{$mod} > $br->{$mod};
    }
    else {
      $br->{$mod} = $tr->{$mod};
    }
  }
}

my $build = Module::Build->new(%module_build_args);

# Git 1.5.4 introduced the --exclude-standard option to git ls-files,
# which Git::Check needs to work properly.
my $need_version = version->parse('1.5.4');
eval {
  my $git_version = `git --version` or die "Unable to execute git\n";
  $git_version =~ /git \s+ version \s* ( \d+ (?: \.\d+ )+ )( [-.]rc\d+)?/x
      or die "Unable to determine git version\n";
  my $rc = $2 || '';

  $git_version = version->parse("$1");
  die "git $need_version or later required, you have $git_version$rc\n"
      if $git_version < $need_version or $git_version == $need_version and $rc;
  1;
} or do {
  print $@;

  if ($build->args('force-install')) {
    print "--force-install specified, attempting to install anyway.\n";
  } else {
    print <<"END MESSAGE";
\nDist::Zilla::Plugin::Git requires git $need_version or later in your PATH,
and it wasn't found.  If you want to install anyway, run

  $^X Build.PL --force-install
END MESSAGE

    exit 0;                  # Indicate missing non-Perl prerequisite
  } # end else not --force-install
}; # end do when Git prerequisite is not met

$build->create_build_script;
