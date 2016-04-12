[![libusnic_verbs release version](https://img.shields.io/github/release/cisco/libusnic_verbs.svg)](https://github.com/cisco/libusnic_verbs/releases/latest)

This is a dummy plugin for libibverbs for Cisco usNIC devices.

It's only purpose in life is to prevent libibverbs from noticing /sys
entries for Cisco usNIC devices and emitting a stderr warning that it
cannot find a userspace plugin to support that device.

Cisco does not support the userspace Verbs API for accessing its usNIC
devices.  The Libfabric API is provided for accessing Cisco usNIC
functionality (see http://libfabric.org/).

Tarballs are available for download from https://github.com/cisco/libusnic_verbs/releases.
