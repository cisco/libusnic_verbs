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

AC_PREREQ(2.57)
AC_INIT(libusnic_verbs, [2.0.0], [http://cisco.com/])
AC_CONFIG_SRCDIR([src/empty_usnic.c])
AC_CONFIG_AUX_DIR(config)
AC_CONFIG_HEADER(config.h)

AM_INIT_AUTOMAKE([-Wall foreign no-define 1.11 subdir-objects])

AC_CONFIG_MACRO_DIR([config])

dnl SILENT_RULES is new in AM 1.11, but we require 1.11 or higher via
dnl autogen.  Limited testing shows that calling SILENT_RULES directly
dnl works in more cases than adding "silent-rules" to INIT_AUTOMAKE
dnl (even though they're supposed to be identical).  Shrug.
AM_SILENT_RULES([yes])

AC_ARG_ENABLE([debug],
    AC_HELP_STRING([--enable-debug],
        [Turn on lots of debugging messages]))
want_debug=0
if test "$enable_debug" = "yes"; then
    want_debug=1
fi
AC_DEFINE_UNQUOTED([WANT_DEBUG_MSGS], [$want_debug], [Whether we want debugging messages or not])

#
# Pull VERSION and RELEASE from VERSION file, allow override
#
AC_MSG_CHECKING([version file])
if test -e $srcdir/RELEASE_VERSION; then
    AC_MSG_RESULT([found tarball version file])
    # If RELEASE_VERSION file exists, we are not in the repository
    . $srcdir/RELEASE_VERSION
elif test -e $srcdir/VERSION; then
    # We are in the source repository
    AC_MSG_RESULT([found repository version file])
    . $srcdir/VERSION
else
    AC_MSG_WARN([No version file found])
    AC_MSG_ERROR([Cannot continue])
fi

AC_MSG_CHECKING([svn repo])
AC_ARG_WITH(svnbranch,
    AC_HELP_STRING([--with-svnbranch],
               [svn branch override (default is no)]))
AC_MSG_CHECKING([with-svnbranch value])
if test -n "$with_svnbranch"; then
    AC_MSG_RESULT([$with_svnbranch])
    USNIC_SVN_BRANCH=$with_svnbranch
elif test -n "$USNIC_SVN_BRANCH"; then
    AC_MSG_RESULT([found [$USNIC_SVN_BRANCH]])
else
    AC_MSG_RESULT([no])
    USNIC_SVN_BRANCH=`svn info $srcdir | grep '^URL:'| awk '{print $2};' | egrep -o '.*(tags|branches)/[[^/]]+|trunk' 2> /dev/null`
	AC_MSG_RESULT([using [$USNIC_SVN_BRANCH]])
fi

AC_ARG_WITH(svnrev,
    AC_HELP_STRING([--with-svnrev],
               [svn revision override (default is no)]))
AC_MSG_CHECKING([with-svnrev value])
if test -n "$with_svnrev"; then
    AC_MSG_RESULT([$with_svnrev])
    USNIC_SVN_REV=$with_svnrev
elif test -n "$USNIC_SVN_REV"; then
    AC_MSG_RESULT([found [$USNIC_SVN_REV]])
else
    AC_MSG_RESULT([none])
    svnrel=`svnversion $srcdir | cut -f1 -d' ' 2> /dev/null`
    if test "${svnrel}" != "${svnrel#[0-9][0-9]}" ; then
        USNIC_SVN_REV=$(echo ${svnrel} | sed s/:/_/g)
    fi
    AC_MSG_RESULT([using [$USNIC_SVN_REV]])
fi

AC_ARG_WITH(version,
	AC_HELP_STRING([--with-version=<a.b.c>],
		[Version number override]))
AC_MSG_CHECKING([with-version value])
if test -n "$with_version"; then
	AC_MSG_RESULT([$with_version])
	USNIC_VERSION=$with_version
else
	AC_MSG_RESULT([none (using $USNIC_VERSION)])
fi

AC_ARG_WITH(release,
	AC_HELP_STRING([--with-release=<a.b.c>],
		[Release number override]))
AC_MSG_CHECKING([with-release value])
if test -n "$with_release"; then
	AC_MSG_RESULT([$with_release])
	USNIC_RELEASE=$with_release
else
    if test ! -z "$USNIC_SVN_REV"; then
        USNIC_RELEASE=rev${USNIC_SVN_REV}
	else
		USNIC_RELEASE=date`date '+%Y%m%d'`
	fi
    USNIC_RELEASE+=$USER
	AC_MSG_RESULT([none (using $USNIC_RELEASE)])
fi

USNIC_WHOLE_VERSION=${USNIC_VERSION}.${USNIC_RELEASE}

#
# Find out what linux distribution
#
RHEL_REL_PATH=/etc/redhat-release
SLES_REL_PATH=/etc/SuSE-release

AC_MSG_CHECKING([Linux distribution])
if test -r "$RHEL_REL_PATH"; then
        LINUX_DISTRO=RHEL
        RPM_BUILD_PKG=redhat-rpm-config
        DISTRO_VER=`cat ${RHEL_REL_PATH} | cut -d " " -f 7 | sed "s/^/rhel/" | sed "s/\./u/"`
elif test -r "$SLES_REL_PATH"; then
        LINUX_DISTRO=SLES
        RPM_BUILD_PKG=rpm-build
	SLES_VER=`cat ${SLES_REL_PATH} | grep "^VERSION" | tr -d " " | cut -d "=" -f 2`
	SLES_PATCHLEVEL=`cat ${SLES_REL_PATH} | grep "^PATCHLEVEL" | tr -d " " | cut -d "=" -f 2`
	DISTRO_VER=sles${SLES_VER}sp${SLES_PATCHLEVEL}
else
        LINUX_DISTRO=""
        RPM_BUILD_PKG=""
        AC_MSG_WARN([Neither RHEL or SLES])
        RPM_DISABLE_WHY="Not a Linux distribution supported for RPM build"
        AC_MSG_WARN([$RPM_DISABLE_WHY])
fi
AC_MSG_RESULT([$LINUX_DISTRO])

if test -n "${LINUX_DISTRO}"; then
	USNIC_WHOLE_VERSION+='.'
	USNIC_WHOLE_VERSION+=${DISTRO_VER}
fi

PACKAGE_VERSION=$USNIC_WHOLE_VERSION
PACKAGE_STRING="$PACKAGE_NAME $PACKAGE_VERSION"
VERSION=$PACKAGE_VERSION

AC_MSG_CHECKING([release date])
if test "$USNIC_REL_DATE"; then
	AC_MSG_RESULT([found [$USNIC_REL_DATE]])
else
    USNIC_REL_DATE=`date +"%D"`
	AC_MSG_RESULT([none (using $USNIC_REL_DATE)])
fi

USNIC_REL_BUILD_USER=`whoami`
USNIC_REL_BUILD_HOST=`uname -n`
USNIC_REL_BUILD_TIMESTAMP=`date`

AC_SUBST(USNIC_VERSION)
AC_SUBST(USNIC_WHOLE_VERSION)
AC_SUBST(USNIC_RELEASE)
AC_SUBST(RPM_RELEASE)
AC_SUBST(USNIC_REL_DATE)
AC_SUBST(USNIC_SVN_BRANCH)
AC_SUBST(USNIC_SVN_REV)

AC_DEFINE_UNQUOTED(USNIC_VERSION, "$USNIC_VERSION", [base version])
AC_DEFINE_UNQUOTED(USNIC_RELEASE, "$USNIC_RELEASE", [release suffix for version])
AC_DEFINE_UNQUOTED(USNIC_WHOLE_VERSION, ["$USNIC_WHOLE_VERSION"], [full version string])
AC_DEFINE_UNQUOTED(USNIC_REL_DATE, ["$USNIC_REL_DATE"], [release date])
AC_DEFINE_UNQUOTED(USNIC_REL_BUILD_USER, "$USNIC_REL_BUILD_USER", [user who made the build])
AC_DEFINE_UNQUOTED(USNIC_REL_BUILD_HOST, "$USNIC_REL_BUILD_HOST", [host on which the build is made])
AC_DEFINE_UNQUOTED(USNIC_REL_BUILD_TIMESTAMP, "$USNIC_REL_BUILD_TIMESTAMP", [build timestamp])
AC_DEFINE_UNQUOTED(USNIC_SVN_BRANCH, "$USNIC_SVN_BRANCH", [SVN branch of the source])
AC_DEFINE_UNQUOTED(USNIC_SVN_REV, "$USNIC_SVN_REV", [SVN revision ranges of the source])

dnl Checks for programs
AC_PROG_CC_C99
AM_PROG_AR

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

#
# Machine settings
#
ARCH=`uname -m`
AC_SUBST(ARCH)

dnl Output files
AC_CONFIG_FILES([
    Makefile
    src/Makefile
    libusnic_verbs.spec])
AC_OUTPUT
