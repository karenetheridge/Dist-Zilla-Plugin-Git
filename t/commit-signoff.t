use strict;
use warnings;

use Dist::Zilla  1.093250;
use Dist::Zilla::Tester;
use File::pushd qw(pushd);
use Path::Tiny 0.012 qw( path ); # ->cwd
use Test::More   tests => 2;

use lib 't/lib';
use Util qw(clean_environment init_repo);

# Mock HOME to avoid ~/.gitexcludes from causing problems
# and clear GIT_ environment variables
my $homedir = clean_environment;

# build fake repository
my $zilla = Dist::Zilla::Tester->from_config({
  dist_root => path('corpus/commit-signoff')->absolute,
});

{
  my $dir = pushd(path( $zilla->tempdir )->child('source'));
  my $git = init_repo( qw{ .  dist.ini Changes } );

  # do a release, with changes and dist.ini updated
  append_to_file('Changes',  "\n");
  append_to_file('dist.ini', "\n");
  $zilla->release;

  # check if dist.ini and changelog have been committed
  my ($log) = $git->log( 'HEAD' );
  like( $log->message, qr/^Signed-off-by: /m, 'commit message signed off' );
  like( $log->message, qr/v1.23\n[^a-z]*foo[^a-z]*bar[^a-z]*baz/,
        'commit message taken from changelog' );
}

sub append_to_file {
    my ($file, @lines) = @_;
    my $fh = path($file)->opena;
    print $fh @lines;
    close $fh;
}
