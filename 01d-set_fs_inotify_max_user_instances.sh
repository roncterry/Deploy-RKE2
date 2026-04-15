#!/bin/bash

# You can either source in the variables from a common config file or
# set them in this script.

CONFIG_FILE=deploy_rke2.cfg

if ! [ -z ${CONFIG_FILE} ]
then
  if [ -e ${CONFIG_FILE} ]
  then
    source ${CONFIG_FILE}
  fi
else
  FS_INOTIFY_MAX_USER_INSTANCES=1024
fi

#------------------------------------------------------------------------------

echo
echo "Setting sysctl fs.inotify.max_user_instances=${FS_INOTIFY_MAX_USER_INSTANCES}"
echo "fs.inotify.max_user_instances=${FS_INOTIFY_MAX_USER_INSTANCES}" > /etc/sysctl.d/50-fs_inotify_max_user_instances.conf
sysctl fs.inotify.max_user_instances=${FS_INOTIFY_MAX_USER_INSTANCES}
echo
