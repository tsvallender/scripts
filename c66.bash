#!/usr/bin/env bash

# Best practice options
set -o nounset
set -o pipefail
if [[ "${TRACE-0}" == "1" ]]; then set -o xtrace; fi

if [[ "${1-}" =~ ^-*h(elp)?$ ]]; then
    echo 'Usage:
      c66 ssh              Select and SSH to a server
      c66 log file role    Select a stack and tail the file “file” on all its servers
'
    exit
fi

pushd ~

############################################################
## Main commands
############################################################

cx_ssh() {
  set_stack
  set_server
  cx ssh --stack $APPLICATION --environment $ENVIRONMENT $SERVER
}

cx_log() {
  set_stack
  OUTPUT_FILE=$(mktemp)
  echo "Logging to $OUTPUT_FILE"
  SERVERS=$(cx servers list --stack $APPLICATION --environment $ENVIRONMENT | grep "\[.*$ROLE.*\]" | cut -d ' ' -f1)
  for SERVER in ${SERVERS// /} ; do
    echo "Following $LOG_FILE on $SERVER"
    cx tail --stack $APPLICATION --environment $ENVIRONMENT $SERVER $LOG_FILE > ./$SERVER.log &
  done
  #tail -f $OUTPUT_FILE
  #pkill cx
}

############################################################
## Helper functions
############################################################

set_stack() {
  STACK=$(cx stacks list | fzf)
  APPLICATION=$(echo $STACK | cut -d ' ' -f1)
  ENVIRONMENT=$(echo $STACK | cut -d ' ' -f2)
}

set_server() {
  SERVER=$(cx servers list --stack $APPLICATION --environment $ENVIRONMENT | fzf | cut -d ' ' -f1)
}

if [[ $# -eq 0 ]] ; then
  echo "No arguments given. Use -h for help."
  exit
fi

if [[ $1 = "ssh" ]] ; then
  cx_ssh
elif [[ $1 = "log" ]] ; then
  LOG_FILE=$2
  ROLE=$3
  cx_log
fi

popd
