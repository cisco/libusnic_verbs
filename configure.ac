# This software is available to you under a choice of one of two
# licenses.  You may choose to be licensed under the terms of the GNU
# General Public License (GPL) Version 2, available from the file
# COPYING in the main directory of this source tree, or the
# BSD license below:
#
#     Redistribution and use in source and binary forms, with or
#     without modification, are permitted provided that the following
#     conditions are met:
#
#      - Redistributions of source code must retain the above
#        copyright notice, this list of conditions and the following
#        disclaimer.
#
#      - Redistributions in binary form must reproduce the above
#        copyright notice, this list of conditions and the following
#        disclaimer in the documentation and/or other materials
#        provided with the distribution.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
# BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
# ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
# CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

dnl Note that the version number in the line below will be edited
dnl by the releng-scripts.
m4_define(libusnic_verbs_version, [2.0.1])

AC_PREREQ(2.57)
AC_INIT([libusnic_verbs], libusnic_verbs_version, [http://cisco.com/])
AC_CONFIG_SRCDIR([src/empty_usnic.c])
AC_CONFIG_AUX_DIR(config)
AC_CONFIG_HEADER(config.h)

AM_INIT_AUTOMAKE([-Wall foreign no-define 1.11 subdir-objects dist-bzip2])

AC_CONFIG_MACRO_DIR([config])

LIBUSNIC_VERBS_VERSION="libusnic_verbs_version"
AC_SUBST(LIBUSNIC_VERBS_VERSION)

dnl SILENT_RULES is new in AM 1.11, but we require 1.11 or higher via
dnl autogen.  Limited testing shows that calling SILENT_RULES directly
dnl works in more cases than adding "silent-rules" to INIT_AUTOMAKE
dnl (even though they're supposed to be identical).  Shrug.
m4_ifdef([AM_SILENT_RULES], [AM_SILENT_RULES([yes])])

dnl Checks for programs
AC_PROG_CC_C99
m4_ifdef([AM_PROG_AR], [AM_PROG_AR])

dnl This library is a plugin, so we'll never want the static library.
LT_INIT([disable-static dlopen])

dnl Checks for libraries
AC_CHECK_LIB(ibverbs, ibv_get_device_list, [],
    AC_MSG_ERROR([ibv_get_device_list() not found.  libusnic_verbs requires libibverbs.]))

dnl Checks for header files.
AC_CHECK_HEADER(infiniband/driver.h, [],
    AC_MSG_ERROR([<infiniband/driver.h> not found.  libusnic_verbs requires libibverbs.]))
AC_HEADER_STDC

dnl Checks for typedefs, structures, and compiler characteristics.
AC_C_CONST
AC_CHECK_SIZEOF(long)

dnl Checks for library functions
AC_CHECK_FUNC(ibv_read_sysfs_file, [],
    AC_MSG_ERROR([ibv_read_sysfs_file() not found.  libusnic_verbs requires libibverbs >= 1.0.3.]))

dnl Check for old versions of libibverbs (that we don't support).  If
dnl we figure out that libibverbs is too old, just abort.
too_old=0
AC_CHECK_FUNC(ibv_dontfork_range,  [], [too_old=1])
AC_CHECK_FUNC(ibv_dofork_range,    [], [too_old=1])
AC_CHECK_FUNC(ibv_register_driver, [], [too_old=1])

AC_MSG_CHECKING([for IBV_CMD_REG_MR_HAS_RESP_PARAMS and IBV_CMD_RESIZE_CQ_HAS_RESP_PARAMS])
AC_COMPILE_IFELSE([AC_LANG_PROGRAM([[
#include <infiniband/verbs.h>
#include <infiniband/driver.h>
]], [[
#if !defined(IBV_CMD_REG_MR_HAS_RESP_PARAMS) || !defined(IBV_CMD_RESIZE_CQ_HAS_RESP_PARAMS)
#error libibverbs is too old
#endif]])],
                  [AC_MSG_RESULT([yes])],
                  [AC_MSG_RESULT([no])
                   too_old=1])

AC_MSG_CHECKING([for IBV_DEVICE_LIBRARY_EXTENSION])
dummy=conftest-if$$.c
cat <<EOF > $dummy
#include <infiniband/driver.h>
IBV_DEVICE_LIBRARY_EXTENSION
EOF
IBV_DEVICE_LIBRARY_EXTENSION=`$CPP $CPPFLAGS $dummy 2> /dev/null | tail -1`
rm -f $dummy
AC_SUBST(IBV_DEVICE_LIBRARY_EXTENSION)
AS_IF([test "$IBV_DEVICE_LIBRARY_EXTENSION" != "IBV_DEVICE_LIBRARY_EXTENSION"],
      [AC_MSG_RESULT([yes ($IBV_DEVICE_LIBRARY_EXTENSION)])],
      [AC_MSG_RESULT([no])
       too_old=1])

dnl Check the result of all of the above "is libibverbs too old?" tests
AS_IF([test $too_old -eq 1],
      [AC_MSG_WARN([Your version of libibverbs is too old.])
       AC_MSG_WARN([Please upgrade to at least v1.1.5.])
                    AC_MSG_ERROR([Cannot continue])])

dnl Check if ld accepts --version-script
AC_CACHE_CHECK([whether ld accepts --version-script], ac_cv_version_script,
    [if test -n "`$LD --help < /dev/null 2>/dev/null | grep version-script`"; then
        ac_cv_version_script=yes
    else
        ac_cv_version_script=no
    fi])
AS_IF([test $ac_cv_version_script = yes],
    [USNIC_VERSION_SCRIPT=])
AC_SUBST(USNIC_VERSION_SCRIPT)

dnl Output files
AC_CONFIG_FILES([
    Makefile
    src/Makefile
    libusnic_verbs.spec])
AC_OUTPUT
