#!/bin/sh

set -e # exit on errors

srcdir=`dirname $0`
test -z "$srcdir" && srcdir=.
git submodule update --init --recursive

autoreconf -vfi
automake --add-missing
./configure
