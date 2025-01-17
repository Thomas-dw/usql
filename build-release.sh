#!/bin/bash

set -e

SRC=$(realpath $(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd))
TAGS="vertica"
VER=$(git tag -l v* $SRC|grep -E '^v[0-9]+\.[0-9]+\.[0-9]+(\.[0-9]+)?$'|sort -r -V|head -1||:)
BUILD=$SRC/build

OPTIND=1
while getopts "b:v:t:" opt; do
case "$opt" in
  b) BUILD=$OPTARG ;;
  v) VER=$OPTARG ;;
  t) TAGS=$OPTARG ;;
esac
done

PLATFORM=$(uname|sed -e 's/_.*//'|tr '[:upper:]' '[:lower:]'|sed -e 's/^\(msys\|mingw\).*/windows/')
ARCH=amd64
NAME=$(basename $SRC)
VER="${VER#v}"
EXT=tar.bz2
DIR=$BUILD/$PLATFORM/$VER
BIN=$DIR/$NAME
case $PLATFORM in
  windows)
    EXT=zip
    BIN=$BIN.exe
  ;;
  linux|darwin)
    TAGS="$TAGS"
  ;;
esac
OUT=$DIR/$NAME-$VER-$PLATFORM-$ARCH.$EXT

pushd $SRC &> /dev/null
echo "APP:         $NAME/${VER} ($PLATFORM/$ARCH)"
if [ ! -z "$TAGS" ]; then
  echo "BUILD TAGS:  $TAGS"
fi
if [ -d $DIR ]; then
  echo "REMOVING:    $DIR"
  rm -rf $DIR
fi
mkdir -p $DIR
echo "BUILDING:    $BIN"
go build \
  -tags "$TAGS" \
  -ldflags="-extldflags=-static" \
  -o $BIN
case $PLATFORM in
  linux|windows|darwin)
    echo "STRIPPING:   $BIN"
    strip $BIN
  ;;
esac
case $PLATFORM in
  linux|windows|darwin)
    COMPRESSED=$(upx -q -q $BIN|awk '{print $1 " -> " $3 " (" $4 ")"}')
    echo "COMPRESSED:  $COMPRESSED"
  ;;
esac
BUILT_VER=$($BIN --version)
if [ "$BUILT_VER" != "$NAME ${VER#v}" ]; then
  echo -e "\n\nerror: expected $NAME --version to report '$NAME ${VER#v}', got: '$BUILT_VER'"
  exit 1
fi
echo "REPORTED:    $BUILT_VER"
case $EXT in
  tar.bz2)
    tar -C $DIR -cjf $OUT $(basename $BIN)
  ;;
  zip)
    zip $OUT -j $BIN
  ;;
esac
echo "PACKED:      $OUT ($(du -sh $OUT|awk '{print $1}'))"
popd &> /dev/null
