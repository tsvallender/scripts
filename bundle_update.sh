#!/usr/bin/env bash

# Best practice options
set -o nounset
set -o pipefail
if [[ "${TRACE-0}" == "1" ]]; then set -o xtrace; fi

if [[ "${1-}" =~ ^-*h(elp)?$ ]]; then
    echo 'Usage:
            bundle_update.sh test_command
'
    exit
fi

declare -a UPDATE_LEVELS=(patch minor major)

TEST_COMMAND=$1
$TEST_COMMAND
if [ $? -ne 0 ]; then
  echo "Tests failed prior to updating any gems. Exiting."
  exit
fi

DATE=`date "+%F"`
git checkout -b "bundle_update_$DATE"

for level in "${UPDATE_LEVELS[@]}"; do
  dip bundle update --$level
  $TEST_COMMAND
  if [ $? -ne 0 ]; then
    echo "Tests failed after $level update, rolling those changes back."
    git restore .
    break
  else
    echo "Tests passed after $level update, committing changes."
    git add -A
    git commit -m "Successful automatic $level update"
  fi
done

git push -u origin $(git symbolic-ref --short HEAD) -o merge_request.create # Create remote branch
