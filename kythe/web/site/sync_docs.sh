#!/bin/bash -e
#
# Copyright 2014 The Kythe Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
#
# Script to sync Kythe documentation into /_docs/ for kythe.io.
#
# Usage: ./sync_docs.sh

# Make sure the user has installed the asciidoc gem, otherwise the website will
# generate successfully but it will be missing tocs, titles, and other
# attributes.
if ! gem list -i asciidoctor &> /dev/null; then
  echo "You don't have the asciidoctor gem installed."
  echo "Please run 'gem install --user asciidoctor' before executing this script."
  exit 1
fi

export SHELL=/bin/bash

DIR="$(readlink -e "$(dirname "$0")")"
cd "$DIR/../../.."

# Use the project's bazelrc so we pick up the default options that Kythe needs
# to build correctly.
bazel --bazelrc=.bazelrc build //kythe/docs/... \
    //kythe/docs:schema-overview \
    //kythe/docs/schema \
    //kythe/docs/schema:callgraph \
    //kythe/docs/schema:verifierstyle \
    //kythe/docs/schema:writing-an-indexer \
    //kythe/docs/schema:indexing-protobuf \
    //kythe/docs/schema:marked-source
# Copy the zipped asciidoc outputs into the staging directory, unpack the
# archives, then remove them. We do this to ensure the output retains the
# directory structure of the source tree.
rsync -Lr --chmod=a+w --delete "bazel-bin/kythe/docs/" "$DIR"/_docs
find "$DIR"/_docs -type f -name '*.zip' -execdir unzip -q {} ';' -delete

DOCS=($(bazel query 'kind("source file", deps(//kythe/docs/..., 1))' | \
  grep -E '\.(txt|adoc|ad)$' | \
  parallel --gnu -L1 'x() { file="$(tr : / <<<"$1")"; echo ${file#//kythe/docs/}; }; x'))

asciidoc_query() {
  bundle exec ruby -r asciidoctor -e 'puts Asciidoctor.load_file(ARGV[0]).'"$2" "$1" 2>/dev/null
}

asciidoc_attribute_presence() {
  [[ "$(asciidoc_query "$1" "attributes[\"$2\"] != nil")" == "true" ]]
}

doc_header() {
  echo "---
layout: page
title: $(asciidoc_query "$1" doctitle)
priority: $(asciidoc_query "$1" 'attributes["priority"]')
toclevels: $(asciidoc_query "$1" 'attributes["toclevels"]')"
  if asciidoc_attribute_presence "$1" toc || asciidoc_attribute_presence "$1" toc2; then
    echo "toc: true"
  fi
echo "---"
}

TMP="$(mktemp)"
trap 'rm -rf "$TMP"' EXIT ERR INT

cd "$DIR"
for doc in ${DOCS[@]}; do
  html=${doc%%.*}.html
  abs_path="../../../kythe/docs/$doc"
  cp "_docs/$html" "$TMP"
  { doc_header "$abs_path";
    cat "$TMP"; } >"_docs/$html"
done

mv _docs/schema/{schema,index}.html
