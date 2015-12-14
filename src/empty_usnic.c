/*
 * Copyright (c) 2015, Cisco Systems, Inc. All rights reserved.
 *
 * This software is available to you under a choice of one of two
 * licenses.  You may choose to be licensed under the terms of the GNU
 * General Public License (GPL) Version 2, available from the file
 * COPYING in the main directory of this source tree, or the
 * BSD license below:
 *
 *     Redistribution and use in source and binary forms, with or
 *     without modification, are permitted provided that the following
 *     conditions are met:
 *
 *      - Redistributions of source code must retain the above
 *        copyright notice, this list of conditions and the following
 *        disclaimer.
 *
 *      - Redistributions in binary form must reproduce the above
 *        copyright notice, this list of conditions and the following
 *        disclaimer in the documentation and/or other materials
 *        provided with the distribution.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
 * BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
 * ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
 * CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

#include "config.h"

#include <stdio.h>
#include <string.h>
#include <stdbool.h>
#include <sys/types.h>
#include <dirent.h>

#include <infiniband/verbs.h>
#include <infiniband/driver.h>

#define PCI_VENDOR_ID_CISCO (0x1137)


static struct ibv_context *fake_alloc_context(struct ibv_device *ibdev,
                                              int cmd_fd)
{
    /* Nothing to do here */
    return NULL;
}

static void fake_free_context(struct ibv_context *ibctx)
{
    /* Nothing to do here */
}

/* Put just enough in here to convince libibverbs that this is a valid
   device, and a little extra just in case someone looks at this
   struct in a debugger. */
static struct ibv_device fake_dev = {
    .ops = {
        .alloc_context = fake_alloc_context,
        .free_context = fake_free_context
    },
    .name = "Cisco usNIC functionality is provided by libfabric"
};

static struct ibv_device *fake_driver_init(const char *uverbs_sys_path,
                                           int abi_version)
{
    char value[8];
    int vendor;

    /* This function should only be invoked for
       /sys/class/infiniband/usnic_X devices, but double check just to
       be absolutely sure: read the vendor ID and ensure that it is
       Cisco. */
    if (ibv_read_sysfs_file(uverbs_sys_path, "device/vendor",
                            value, sizeof(value)) < 0) {
        return NULL;
    }
    if (sscanf(value, "%i", &vendor) != 1) {
        return NULL;
    }

    if (vendor == PCI_VENDOR_ID_CISCO) {
        return &fake_dev;
    }

    /* We didn't find a device that we want to support */
    return NULL;
}


static __attribute__ ((constructor)) void usnic_register_driver(void)
{
    /* If there are any usnic devices, then register a fake driver */
    DIR *class_dir;
    class_dir = opendir("/sys/class/infiniband");
    if (NULL == class_dir) {
        return;
    }

    bool found = false;
    struct dirent *dent;
    while ((dent = readdir(class_dir)) != NULL) {
        if (strncmp(dent->d_name, "usnic_", 6) == 0) {
            found = true;
            break;
        }
    }
    closedir(class_dir);

    if (found) {
        ibv_register_driver("usnic_verbs", fake_driver_init);
    }
}
