#!/usr/bin/env perl
#
# Common functionality for libusnic_verbs releng scripts.
#

package Cisco::libusnic_verbs_noop;

use strict;
use warnings;

use Cwd;
use File::Basename;
use Data::Dumper;
use Getopt::Long;
use POSIX qw(strftime);

use Cisco::usnic_releng_common;

#--------------------------------------------------------------------------

# Simplification for use below
sub do_command {
    Cisco::usnic_releng_common::do_command(@_);
}

#--------------------------------------------------------------------------

my @argv_save = @ARGV;
our @timestamp = localtime;

sub sanity_check {
    # Sanity checks
    die "Must be run from the top-level libusnic_verbs_noop-releng directory"
        if (! -d "Cisco" || ! -f "Cisco/usnic_releng_common.pm");
    my $upstream_version_file = "UPSTREAM_VERSION";
    die "Can't find $upstream_version_file file"
        if (! -r $upstream_version_file);
    my $cisco_version_file = "version.sh";
    die "Can't find Cisco $cisco_version_file file"
        if (! -r $cisco_version_file);

    # Ensure we don't have any whacky version of gcc in the path.
    # Unload all modules and re-run.
    if (exists($ENV{LOADEDMODULES}) &&
        $ENV{LOADEDMODULES} =~ /gcc/) {
        print "=== Unloading a bunch of environment modules and re-running...\n";
        my $ret = system(". /etc/profile.d/modules.sh ; module unload gcc cisco/gcc cisco/intel-compilers cisco/pgi-compilers cisco/clang-compilers; $0 " .
                         join(' ', @argv_save));
        exit($ret);
    }
}

#--------------------------------------------------------------------------

my $debug_arg = 0;
my $logfile_dir_arg;
my $cisco_maintainer_arg = "Jeff Squyres";
my $cisco_maintainer_email_arg = "jsquyres\@cisco.com";

sub parse_argv {
    my $help_arg;

    &Getopt::Long::Configure("bundling");
    my $ok = Getopt::Long::GetOptions("maintainer=s" => \$cisco_maintainer_arg,
                                      "maintainer-email=s" => \$cisco_maintainer_email_arg,
                                      "logfile-dir=s" => \$logfile_dir_arg,
                                      "debug!" => \$debug_arg,
                                      "help|h" => \$help_arg);

    $help_arg = 1
        if (!$ok);
    if ($help_arg) {
        print "$0 [--logfile-dir=DIR|--git-repo-url=URL|--debug|--help]

--logfile-dir=DIR  Directory to write various logfiles
--git-repo-url=URL URL of the git repo to clone
--debug            Shows the commands being run, and their output
--help             Shows this message\n";
        exit($ok);
    }

    # Setup the helpers with the CLI args
    Cisco::usnic_releng_common::init($debug_arg, $logfile_dir_arg);

    my $ret = {
        maintainer => $cisco_maintainer_arg,
        maintainer_email => $cisco_maintainer_email_arg,
    };
    return $ret;
}

#--------------------------------------------------------------------------

sub update_git {
    my $git_id = shift;
    do_command("git checkout $git_id");
}

#--------------------------------------------------------------------------

sub read_upstream_version {
    my $upstream_version_file = shift;

    # Read meta data from $upstream_version_file
    open(IN, $upstream_version_file)
        || die "Can't open $upstream_version_file";
    my $upstream_git_id;
    while (<IN>) {
        # Skip comments
        next
            if (/^\s*#/);

        # Look for "GIT_ID=<id>"
        $upstream_git_id = $1
            if (m/\s*GIT_ID\s*=\s*(.+)\n/);
    }

    die "Couldn't find GIT_ID in $upstream_version_file"
        if (!defined($upstream_git_id));
    print "=== Found upstream git ID in $upstream_version_file: $upstream_git_id\n";

    return $upstream_git_id;
}

sub read_cisco_version {
    my $cisco_version_file = shift;

    die "Can't run ./$cisco_version_file"
        if (! -x $cisco_version_file);

    my $cisco_version = `./$cisco_version_file --version`;
    chomp($cisco_version);
    my $cisco_build_id = `./$cisco_version_file --build-id`;
    chomp($cisco_build_id);

    print "=== Found Cisco version: $cisco_version, build ID: $cisco_build_id\n";

    return $cisco_version, $cisco_build_id;
}

#--------------------------------------------------------------------------

sub make_tarball {
    my $version = shift;

    # Autogen, configure, make dist.
    print "=== Running autogen.sh...\n";
    do_command("./autogen.sh", "autogen");

    print "=== Making libusnic_verbs (noop) version $version\n";

    print "=== Running configure...\n";
    do_command("./configure", "configure");

    unlink("libusnic_verbs_noop-$version.tar.bz2")
        if (-f "libusnic_verbs_noop-$version.tar.bz2");
    unlink("libusnic_verbs_noop-$version.tar.gz")
        if (-f "libusnic_verbs_noop-$version.tar.gz");

    my $dist_target = "distcheck";
    $dist_target = "dist"
        if ($debug_arg);

    print "=== Running make $dist_target...\n";
    do_command("make $dist_target", "make-distcheck");
}

#------------------------------------------------------------------------

my $src_version;
my $pkg_version;
my $pkg_release;
my $cisco_maintainer;
my $cisco_maintainer_email;
my $configure_args;

sub modify_file_contents_setup {
    $src_version = shift;
    $pkg_version = shift;
    $pkg_release = shift;
    $cisco_maintainer = shift;
    $cisco_maintainer_email = shift;
    $configure_args = shift;
}

sub modify_file_contents {
    my $contents = shift;

    my $release_date = strftime("%a, %d %b %Y %H:%M:%S %z", @timestamp);

    $contents =~ s/\@LIBUSNIC_VERBS_SRC_VERSION\@/$src_version/g;
    $contents =~ s/\@LIBUSNIC_VERBS_PKG_VERSION\@/$pkg_version/g;
    $contents =~ s/\@LIBUSNIC_VERBS_PKG_RELEASE\@/$pkg_release/g;
    $contents =~ s/\@RELEASE_DATE\@/$release_date/g;
    $contents =~ s/\@CONFIGURE_ARGS\@/$configure_args/g;

    $contents =~ s/\@CISCO_MAINTAINER\@/$cisco_maintainer/g;
    $contents =~ s/\@CISCO_MAINTAINER_EMAIL\@/$cisco_maintainer_email/g;

    return $contents;
}

1;
