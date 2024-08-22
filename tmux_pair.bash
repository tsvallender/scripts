#!/usr/bin/env bash

# Best practice options
set -o errexit
set -o nounset
set -o pipefail
if [[ "${TRACE-0}" == "1" ]]; then set -o xtrace; fi

if [[ "${1-}" =~ ^-*h(elp)?$ ]]; then
    echo 'Usage:
    tp new      Start a new tmux session (unshared)
    tp sharero  Share an existing session (read-only)
    tp sharew   Share an existing session (write-access)
    tp unshare  Remove share from existing session
'
    exit
fi

pushd ~

SOCKET_PATH="/var/tmux_share/shared"
SHARED_USER="foxsoft" # Should change this to use getent group tmux

share_ro_session() {
  chmod 770 $SOCKET_PATH
  chgrp tmux $SOCKET_PATH
  tmux -S $SOCKET_PATH server-access -ar $SHARED_USER
}

share_rw_session() {
  chmod 770 $SOCKET_PATH
  chgrp tmux $SOCKET_PATH
  tmux -S $SOCKET_PATH server-access -aw $SHARED_USER
}

unshare_session() {
  chmod 700 $SOCKET_PATH
  tmux -S $SOCKET_PATH server-access -d $SHARED_USER
}

new_session() {
  tmux -S $SOCKET_PATH new -s shared -d
  tmux -S $SOCKET_PATH attach
}

attach_to_session() {
  tmux -S $SOCKET_PATH attach
}

if [[ $# -eq 0 ]] ; then
  echo "No arguments given. Use -h for help."
  exit
fi

touch $SOCKET_PATH

if [[ $1 = "new" || $1 = "n" ]] ; then
  new_session
elif [[ $1 = "sharero" || $1 = "sro" ]] ; then
  share_ro_session
elif [[ $1 = "sharew" || $1 = "srw" ]] ; then
  share_rw_session
elif [[ $1 = "unshare" ]] ; then
  unshare_session
elif [[ $1 = "attach" || $1 = "a" ]] ; then
  attach_to_session
else
  echo "Unrecognised argument. Use -h for help."
fi

popd
