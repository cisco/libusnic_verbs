[![libusnic_verbs release version](https://img.shields.io/github/release/cisco/libusnic_verbs.svg)](https://github.com/cisco/libusnic_verbs/releases/latest)

This is a dummy plugin for libibverbs for Cisco usNIC devices.

This package is *only* necessary for older Linux distros that include
legacy versions of the libibverbs library.  For example, this package
is no longer necessary for Red Hat Enterprise Linux (RHEL) starting
with version 7.4, and is also no longer necessary starting with SuSE
Enterprise Linux 12 SP3.

It's only purpose in life is to prevent libibverbs from noticing /sys
entries for Cisco usNIC devices and emitting a stderr warning that it
cannot find a userspace plugin to support that device.

Cisco does not support the userspace Verbs API for accessing its usNIC
devices.  The Libfabric API is provided for accessing Cisco usNIC
functionality (see http://libfabric.org/).

Tarballs are available for download from https://github.com/cisco/libusnic_verbs/releases.

-----

The intent for this package is  to install the usnic libibverbs plugin
in the same location as all other libibverbs plugins, and also install
the `usnic.driver`  meta data text  file in  the same location  as all
ther other libibverbs meta data text files.

For example, here's the correct `configure` line to build this package
to install all the files in the correct location for RHEL 6 and 7:

```
$ ./configure --prefix=/usr --sysconfdir=/etc --libdir=/usr/lib64
$ make
$ sudo make install
```
