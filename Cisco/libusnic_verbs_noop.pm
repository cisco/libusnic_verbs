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
    my $cisco_version_file = "VERSION";
    die "Can't find Cisco VERSION file"
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

    die "configure.ac is dirty; exiting"
        if (`git status configure.ac --porcelain` ne "");
}

#--------------------------------------------------------------------------

my $debug_arg = 0;
my $logfile_dir_arg;
my $cisco_maintainer_arg = "Jeff Squyres";
my $cisco_maintainer_email_arg = "jsquyres\@cisco.com";

sub parse_argv {
    my $build_arg;
    my $help_arg;

    &Getopt::Long::Configure("bundling");
    my $ok = Getopt::Long::GetOptions("build=s" => \$build_arg,
                                      "maintainer=s" => \$cisco_maintainer_arg,
                                      "maintainer-email=s" => \$cisco_maintainer_email_arg,
                                      "logfile-dir=s" => \$logfile_dir_arg,
                                      "debug!" => \$debug_arg,
                                      "help|h" => \$help_arg);

    $help_arg = 1
        if (!$ok);
    if ($help_arg) {
        print "$0 --build=BUILD_ID [--logfile-dir=DIR|--git-repo-url=URL|--debug|--help]

--build=BUILD_ID   Sets the build ID
--logfile-dir=DIR  Directory to write various logfiles
--git-repo-url=URL URL of the git repo to clone
--debug            Shows the commands being run, and their output
--help             Shows this message\n";
        exit($ok);
    }

    if (!defined($build_arg)) {
        print "ERROR: Must supply a --build argument\n";
        exit(1);
    }

    # Setup the helpers with the CLI args
    Cisco::usnic_releng_common::init($debug_arg, $logfile_dir_arg);

    my $ret = {
        build_arg => $build_arg,
        maintainer => $cisco_maintainer_arg,
        maintainer_email => $cisco_maintainer_email_arg,
    };
    return $ret;
}

#--------------------------------------------------------------------------

sub update_git {
    # Read meta data from VERSION
    open(IN, "VERSION")
        || die "Can't open VERSION";
    my $git_id;
    while (<IN>) {
        # Skip comments
        next
            if (/^\s*#/);

        # Look for "GIT_ID=<id>"
        $git_id = $1
            if (m/\s*GIT_ID\s*=\s*(.+)\n/);
    }

    if (defined($git_id)) {
        print "=== Updating to Git ID $git_id\n";
        do_command("git update $git_id");
    }
}

#--------------------------------------------------------------------------

sub update_configure_version {
    my $build_arg = shift;

    print "=== Build number: $build_arg\n";

    # Get the distro + version
    my $distro = Cisco::usnic_releng_common::find_distro();
    print "=== Found distro: $distro\n";

    # Get this package version from configure.ac
    open(IN, "configure.ac") || die "Can't open git-cloned configure.ac";
    my $configure_ac;
    $configure_ac .= $_
        while (<IN>);
    close(IN);

    $configure_ac =~ m/m4_define\(libusnic_verbs_version,\s*\[(.+)\]\)/ ||
        die "Unable to find version number in configure.ac";
    my $version = $1;
    print "=== Found configure.ac version: $version\n";

    # Add in the build number and the distro
    my $new_version .= "$version.$build_arg.$distro";
    print "=== Updating configure.ac version to: $new_version\n";

    $configure_ac =~ s/(m4_define\(libusnic_verbs_version,\s*\[)(.+)\)/$1$new_version]\)/ ||
        die "Unable to modify version in configure.ac";

    # Write out the new configure.ac
    $version = $new_version;
    print "=== Re-writing configure.ac with Cisco version: $version\n";
    open(OUT, ">configure.ac") || die "Can't write to configure.ac";
    print OUT $configure_ac;
    close(OUT);

    return $version;
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

my $version;
my $cisco_maintainer;
my $cisco_maintainer_email;
my $configure_args;

sub modify_file_contents_setup {
    $version = shift;
    $cisco_maintainer = shift;
    $cisco_maintainer_email = shift;
    $configure_args = shift;
}

sub modify_file_contents {
    my $contents = shift;

    my $release_date = strftime("%a, %d %b %Y %H:%M:%S %z", @timestamp);

    $contents =~ s/\@LIBUSNIC_VERBS_VERSION\@/$version/g;
    $contents =~ s/\@RELEASE_DATE\@/$release_date/g;
    $contents =~ s/\@CONFIGURE_ARGS\@/$configure_args/g;

    $contents =~ s/\@CISCO_MAINTAINER\@/$cisco_maintainer/g;
    $contents =~ s/\@CISCO_MAINTAINER_EMAIL\@/$cisco_maintainer_email/g;

    return $contents;
}

1;
