#!/usr/bin/env bash

# Best practice options
set -o errexit
set -o nounset
set -o pipefail
if [[ "${TRACE-0}" == "1" ]]; then set -o xtrace; fi

if [[ "${1-}" =~ ^-*h(elp)?$ ]]; then
    echo 'Usage:
'
    exit
fi

INPUT_DIR=~/notes/site
OUTPUT_DIR=~/public_html

pushd ~

# Recursively iterate over directories, calling process_file on .md files
traverse_dir() {
  local dir=$1
  local depth=$2
  for d in $dir; do
    OUTPUT=$OUTPUT_DIR${d##$INPUT_DIR}
    if [ -d "$d" ]; then
      mkdir -p  $OUTPUT
      traverse_dir "$d/*" $((depth+1))
    elif [[ $d == *.md ]]; then
      OUTPUT=${OUTPUT%.md}.html
      process_file "$d" "$OUTPUT" $depth
    fi
  done
}

# Take a Markdown file and process it to HTML
process_file() {
  local INPUT=$1
  local OUTPUT=$2
  local depth=$3
  local TITLE=${INPUT%.md}
  TITLE=${TITLE##*/}
  if [ "$TITLE" == 'index' ]; then
    TITLE='Home'
  fi
  pandoc -f markdown -t html -o "$OUTPUT" -i "$INPUT" --standalone --template ~/code/site/template.html --variable=pagetitle:"$TITLE"
  replace_links "$OUTPUT" $depth
}

# Replace links in Markdown files with working links to the new HTML files
replace_links() {
  local FILE=$1
  local depth=$2
  # Add .html extensions
  sed -Ei.bak '/https|\.[a-z]+/!s/href="[^"]*/&.html/' "$FILE"
  if [ "$depth" -gt 0 ]; then
    local path=$(for each in $(seq 1 $depth); do printf "..\/"; done)
    local href="${path}style.css"
    sed -i "s/href='style.css'/href='${href}'/g" "$FILE"
  fi
}

setup_files() {
  cp -r ~/code/site/assets/ ~/public_html/
  cp ~/code/site/style.css ~/public_html
}

traverse_dir $INPUT_DIR/\* 0
setup_files
rsync -arz ~/public_html/* -e ssh tsv@kernighan:/var/www/tsvallender.co.uk

popd
