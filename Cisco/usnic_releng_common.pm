#!/usr/bin/env perl
#
# Common functionality for usnic releng scripts.
#

package Cisco::usnic_releng_common;

use strict;
use warnings;

my $debug_arg;
my $logfile_dir_arg;

#--------------------------------------------------------------------------

# Setup globals for this file
sub init {
    $debug_arg = shift;
    $logfile_dir_arg = shift;
}

#--------------------------------------------------------------------------

# run a command and save the stdout / stderr
sub do_command {
    my ($cmd) = shift;
    my ($logfilename) = shift;

    print "*** Running command: $cmd\n" if ($debug_arg);
    pipe OUTread, OUTwrite;

    # Child

    my $pid;
    if (($pid = fork()) == 0) {
        close OUTread;

        close(STDERR);
        open STDERR, ">&OUTwrite"
            || die "Can't redirect stderr\n";
        select STDERR;
        $| = 1;

        close(STDOUT);
        open STDOUT, ">&OUTwrite"
            || die "Can't redirect stdout\n";
        select STDOUT;
        $| = 1;

        # Turn shell-quoted words ("foo bar baz") into individual tokens

        my @tokens;
        while ($cmd =~ /\".*\"/) {
            my $prefix;
            my $middle;
            my $suffix;

            $cmd =~ /(.*?)\"(.*?)\"(.*)/;
            $prefix = $1;
            $middle = $2;
            $suffix = $3;

            if ($prefix) {
                foreach my $token (split(' ', $prefix)) {
                    push(@tokens, $token);
                }
            }
            if ($middle) {
                push(@tokens, $middle);
            } else {
                push(@tokens, "");
            }
            $cmd = $suffix;
        }
        if ($cmd) {
            push(@tokens, split(' ', $cmd));
        }

        # Run it!

        exec(@tokens) ||
            die "Can't execute command: $cmd\n";
    }
    close OUTwrite;

    # Parent

    my (@out);
    my ($rin, $rout);
    my $done = 1;

    # Keep watching over the pipe(s)

    $rin = '';
    vec($rin, fileno(OUTread), 1) = 1;

    while ($done > 0) {
        my $nfound = select($rout = $rin, undef, undef, undef);

        if (vec($rout, fileno(OUTread), 1) == 1) {
            my $data = <OUTread>;
            if (!defined($data)) {
                vec($rin, fileno(OUTread), 1) = 0;
                --$done;
            } else {
                push(@out, $data);
                print "OUT:$data" if ($debug_arg);
            }
        }
    }

    # The pipes are closed, so the process should be dead.  Reap it.

    waitpid($pid, 0);
    my $status = $?;
    print "*** Command complete, exit status: $status\n" if ($debug_arg);

    # Return an anonymous hash containing the relevant data

    my $ret = {
        stdout_and_stderr => \@out,
        status => $status
        };

    # If a log filename was given, and we have a logfile dir, then
    # write logfiles for stdout/stderr.
    if (defined($logfilename) && defined($logfile_dir_arg)) {
        my $filename = "$logfile_dir_arg/$logfilename";

        # Exit status
        open(OUT, ">$filename-status.out") ||
            die "Can't write to $filename-status.out";
        print OUT "Exit status: $status\n";
        close(OUT);

        # Stdout+stderr
        if ($#out >= 0) {
            open(OUT, ">$filename-stdout-stderr.out") ||
                die "Can't write to $filename-stdout-stderr.out";
            print OUT @out;
            close(OUT);
        }
    }

    # If we failed, just die
    if ($ret->{status} != 0) {
        print "=== Failed to $cmd\n";
        print "=== Last few lines of stdout/stderr:\n";
        my $i = $#{$ret->{stdout_and_stderr}} - 500;
        $i = 0
            if ($i < 0);
        while ($i <= $#{$ret->{stdout_and_stderr}}) {
            print $ret->{stdout_and_stderr}[$i];
            ++$i;
        }
        exit(1);
    }

    return $ret;
}

#--------------------------------------------------------------------------

# Get the distro version.
# Understands RHEL 6,7, SLES 12, and Ubuntu 14 LTS
sub find_distro {
    my $distro;
    my $rhel_rel_path = "/etc/redhat-release";
    my $sles_rel_path = "/etc/SuSE-release";
    my $lsb_rel_path = "/etc/lsb-release";

    # RHEL 6, 7
    if (-r $rhel_rel_path) {
        $distro = `cat $rhel_rel_path | cut -d " " -f 7 | sed "s/^/rhel/" | sed "s/\\\./u/"`;
    }

    # SLES 12
    elsif (-r $sles_rel_path) {
        my $ver = `cat $sles_rel_path | grep "^VERSION" | tr -d " " | cut -d "=" -f 2`;
        chomp($ver);
        my $patchlevel = `cat $sles_rel_path | grep "^PATCHLEVEL" | tr -d " " | cut -d "=" -f 2`;
        $distro = "sles${ver}sp${patchlevel}";
    }

    # Ubuntu 14 LTS
    elsif (-r $lsb_rel_path) {
        open(IN, $lsb_rel_path) ||
            die "Can't open $lsb_rel_path";
        my $lsb_fields;
        while (<IN>) {
            chomp;
            my ($field, $value) = split('=', $_);
            $lsb_fields->{$field} = $value;
        }
        close(IN);

        if ($lsb_fields->{'DISTRIB_ID'} eq "Ubuntu" ||
            $lsb_fields->{'DISTRIB_RELEASE'} eq "14.04") {
            $distro = "ubuntu1404lts";
        } else {
            die "*** Unknown Linux distro: $lsb_fields->{'DISTRIB_ID'} / $lsb_fields->{'DISTRIB_RELEASE'}";
        }
    }

    # Shrug
    else {
        die "*** Unknown Linux distro -- aborting build";
    }

    chomp($distro);
    return $distro;
}

#--------------------------------------------------------------------------

sub read_mod_write {
    my $filename_in = shift;
    my $filename_out = shift;
    my $cb_func = shift;

    print "=== Modifying file $filename_in -> $filename_out\n";

    # Read the file
    open(IN, $filename_in) ||
        die "Can't open $filename_in";
    my $contents;
    $contents .= $_
        while (<IN>);
    close(IN);

    # Invoke the callback to modify the contents
    my $new_contents = &{$cb_func}($contents);

    # Write the output file
    unlink($filename_out);
    open(OUT, ">$filename_out") ||
        die "Can't write to $filename_out";
    print OUT $new_contents;
    close(OUT);
}

#------------------------------------------------------------------------

sub check_git_config {
    my $config = shift;
    my $value = shift;

    my $rc = system("git config --get $config > /dev/null");
    do_command("git config --add $config \"$value\"")
        if (0 != $rc);
}

sub apply_local_patches {
    my $dir = shift;

    return
        if (! -d $dir);

    die "Unexpectedly unable to open $dir"
        if (!opendir(my $dh, "$dir"));
    my @files = grep { /^\d.+\.patch$/ && -f "$dir/$_" } readdir($dh);
    closedir($dh);

    # Double check that this git user has global config setup first
    check_git_config("user.email", "usnic-engineering\@cisco.com");
    check_git_config("user.name", "usNIC Engineering");

    foreach my $patch (sort(@files)) {
        print "=== Applying local patch: $patch\n";
        do_command("git am $dir/$patch");
    }
}

#------------------------------------------------------------------------

return 1;
