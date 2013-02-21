#!/bin/bash

set -e

if [ ! -f Makefile.PL ]; then
    echo "$0: Must be executed from top of the yubico-perl-client dir."
    exit 1
fi

PACKAGE="AnyEvent-Yubico"
VERSION=$(cat lib/AnyEvent/Yubico.pm | grep "our \$VERSION" | sed 's/^[^0-9]*\([0-9]\{1,\}\(\.[0-9]\{1,\}\)*\)[^0-9]*$/\1/g')

if [ "$(git tag | grep $PACKAGE-$VERSION)" == "$PACKAGE-$VERSION" ]; then
    echo "git tag '$PACKAGE-$VERSION' already exists! Did you forget to update the version number?"
    exit 1
fi

do_test="true"
do_sign="true"

if [ "x$1" == "x--no-test" ]; then
    do_test="false"
    shift
fi

KEYID=$1
if [ "x$KEYID" == "x" ]; then
    echo "Syntax: $0 [--no-test] <KEYID>";
    exit 1;
fi

perl Makefile.PL

if [ "x$do_test" != "xfalse" ]; then
    make test
fi

make dist
make distclean

#Create signature
gpg --detach-sign --default-key $KEYID $PACKAGE-$VERSION.tar.gz
gpg --verify $PACKAGE-$VERSION.tar.gz.sig

git tag -u $KEYID -m $VERSION $PACKAGE-$VERSION

