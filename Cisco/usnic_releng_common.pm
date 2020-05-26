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
# A specific set of distros are understood; see the code below.
sub find_distro {
    my $distro;
    my $os_rel_path = "/etc/os-release";
    my $found = 0;

    # Generic distro.  This is the most portable / modern (as of June
    # 2018).
    if (-r $os_rel_path) {
        # Read the file and save the values in a hash
        open(IN, $os_rel_path) ||
            die "Can't open $os_rel_path";
        my $os_fields;
        while (<IN>) {
            chomp;
            if ($_ ne "") {
                my ($field, $value) = split('=', $_);
                $value = $1
                    if ($value =~ m/^"(.+)"$/);
                $os_fields->{$field} = $value;
            }
        }
        close(IN);

        # RHEL 8.x
        # RHEL 7.x
        # (RHEL 6.x does not have /etc/os-release)
        if ($os_fields->{'NAME'} =~ 'Red Hat Enterprise Linux') {
            # Convert "X.Y" to "XuY"
            if ($os_fields->{'VERSION_ID'} =~ m/^([78])\.(\d+)$/) {
                $distro = "rhel$1u$2";
            }
        }

        # SLES 12,15 (including SPs)
        elsif ($os_fields->{'NAME'} eq 'SLES') {
            # Might find "X" or "X.Y"
            # Convert "X.Y" into "XspY"
            if ($os_fields->{'VERSION_ID'} =~ m/^(1[25])$/) {
                $distro = "sles$1";
            } elsif ($os_fields->{'VERSION_ID'} =~ m/^(1[25])\.(\d+)$/) {
                $distro = "sles$1sp$2";
            }
        }

        # Ubuntu 14,16,18,20 LTS
        elsif ($os_fields->{'NAME'} eq 'Ubuntu') {
            # Remove the ".": 14.04 -> "1404"
            if ($os_fields->{'VERSION_ID'} =~ m/(1[468])\.04/) {
                $distro = "ubuntu$1" . "04lts";
            } elsif ($os_fields->{'VERSION_ID'} =~ m/20\.04/) {
                $distro = "ubuntu2004lts";
            }
        }
    }

    # Old / distro-specific methods.
    # RHEL 6
    my $rhel_rel_path = "/etc/redhat-release";
    if (!defined($distro) && -r $rhel_rel_path) {
        $distro = `cat $rhel_rel_path | cut -d " " -f 7 | sed "s/^/rhel/" | sed "s/\\\./u/"`;
    }

    # Shrug
    if (!defined($distro)) {
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

#------------------------------------------------------------------------

sub count_linux_processors {
    # Count how many processors we have (that we can use for the
    # parallel build).
    open(IN, "/proc/cpuinfo") || die "Can't open /proc/cpuinfo";
    my $proc_count = 0;
    while (<IN>) {
        chomp;
        ++$proc_count
            if ($_ =~ /^processor(\s+): \d+$/);
    }
    close(IN);

    print "=== Counted $proc_count Linux processors (via /proc/cpuinfo)\n";
    return $proc_count;
}

#------------------------------------------------------------------------

return 1;
