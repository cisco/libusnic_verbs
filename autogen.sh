#! /bin/sh

set -x
if test ! -d config; then
    mkdir config
fi
autoreconf -ivf
