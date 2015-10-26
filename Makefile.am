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

SUBDIRS = src
VPATH = $(srcdir)

ACLOCAL_AMFLAGS = -I config

AM_CFLAGS = -g -Wall -Wextra -D_GNU_SOURCE

USNIC_WHOLE_VERSION=@USNIC_WHOLE_VERSION@
RPM_RELEASE=@RPM_RELEASE@
USNIC_VERSION=@USNIC_VERSION@
USNIC_RELEASE=@USNIC_RELEASE@
USNIC_REL_DATE=@USNIC_REL_DATE@
USNIC_SVN_BRANCH=@USNIC_SVN_BRANCH@
USNIC_SVN_REV=@USNIC_SVN_REV@

EXTRA_DIST = \
	libusnic_verbs.spec.in \
	usnic.driver

# This is a workaround for a bug in automake:
# http://debbugs.gnu.org/cgi/bugreport.cgi?bug=14594
EXTRA_DIST += config/depcomp
EXTRA_DIST += LICENSE

usnicconfdir = $(sysconfdir)/libibverbs.d
usnicconf_DATA = usnic.driver

define gen_release_version
	@echo "#Auto Generated - Do not edit" >> $(distdir)/RELEASE_VERSION
	@echo "USNIC_VERSION=$(USNIC_VERSION)" >> $(distdir)/RELEASE_VERSION
	@echo "USNIC_REL_DATE=$(USNIC_REL_DATE)" >> $(distdir)/RELEASE_VERSION
	@echo "USNIC_SVN_BRANCH=$(USNIC_SVN_BRANCH)" >> \
					$(distdir)/RELEASE_VERSION
	@echo "USNIC_SVN_REV=$(USNIC_SVN_REV)" >> $(distdir)/RELEASE_VERSION
	@echo "RPM_RELEASE=$(RPM_RELEASE)" >> $(distdir)/RELEASE_VERSION
endef

define insert_license
	files=$$(find $(distdir) -type f); \
	for file in $${files}; do \
		sed -i \
			-e '/^ \* \[Insert appropriate license here/r $(distdir)/LICENSE' \
			-e '/^ \* \[Insert appropriate license here/d' $${file}; \
	done
	rm -rf $(distdir)/LICENSE
endef

dist-hook:
	$(gen_release_version)
	$(insert_license)

libusnic_verbs_src_rpm = libusnic_verbs-${USNIC_WHOLE_VERSION}-${RPM_RELEASE}.src.rpm

$(libusnic_verbs_src_rpm): dist
	rpmbuild --define "_topdir $(abs_builddir)/rpmbuild" \
	    --define "usnic_version ${USNIC_WHOLE_VERSION}" \
	    --define "_sourcedir $(abs_builddir)" -bs libusnic_verbs.spec
	mv rpmbuild/SRPMS/$(libusnic_verbs_src_rpm) .

.PHONY: valgrind_rpm
valgrind_rpm: $(libusnic_verbs_src_rpm)
	rpmbuild --rebuild \
	    --define "_topdir $(abs_builddir)/rpmbuild" \
	    --define "usnic_release ${USNIC_RELEASE}" \
	    --define "usnic_version ${USNIC_WHOLE_VERSION}" \
		--define "valgrind $(VALGRIND_PATH)" \
	    $(libusnic_verbs_src_rpm)

.PHONY: releng
releng: $(libusnic_verbs_src_rpm) $(VALGRIND_RPM)
	rpmbuild --rebuild \
	    --define "_topdir $(abs_builddir)/rpmbuild" \
	    --define "usnic_release ${USNIC_RELEASE}" \
	    --define "usnic_version ${USNIC_WHOLE_VERSION}" \
	    $(libusnic_verbs_src_rpm)
	mv rpmbuild/RPMS/$(ARCH)/* .

clean-local: clean-local-check
.PHONY: clean-local-check
clean-local-check:
	-rm -rf *.rpm rpmbuild *.tar.gz
