#!/bin/sh

set -e # exit on errors

srcdir=`dirname $0`
test -z "$srcdir" && srcdir=.

autoreconf -vfi
automake --add-missing
./configure
