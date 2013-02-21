#!/bin/bash

set -e

if [ ! -f Makefile.PL ]; then
    echo "$0: Must be executed from top of the yubico-perl-client dir."
    exit 1
fi

PACKAGE="AnyEvent-Yubico"
VERSION=$(cat lib/AnyEvent/Yubico.pm | grep "our \$VERSION" | sed 's/^[^0-9]*\([0-9]\{1,\}\(\.[0-9]\{1,\}\)*\)[^0-9]*$/\1/g')

echo "Releasing $PACKAGE version $VERSION...";

if [ "$(git tag | grep $PACKAGE-$VERSION)" == "$PACKAGE-$VERSION" ]; then
    echo "git tag '$PACKAGE-$VERSION' already exists! Did you forget to update the version number?"
    exit 1
fi

PATTERN="$VERSION  $(date '+%a %b %d [0-9]\{2\}:[0-9]\{2\}:[0-9]\{2\} %Y')"
if [ ! "$(cat Changes | grep -e "$PATTERN")" ]; then
    echo "Changes does not have an entry matching $VERSION with todays date."
    echo "Make sure there is a line that has the following form:"
    echo "$VERSION  $(date '+%a %b %d %T %Y')"
    exit 1
fi

do_test="true"
do_publish="true"

if [ "x$1" == "x--no-test" ]; then
    echo "Skip tests"
    do_test="false"
    shift
fi

if [ "x$1" == "x--no-publish" ]; then
    echo "Do not publish release"
    do_publish="false"
    shift
fi

KEYID=$1
if [ "x$KEYID" == "x" ]; then
    echo "Syntax: $0 [--no-test] [--no-publish] <KEYID>";
    exit 1;
fi

perl Makefile.PL

if [ "x$do_test" != "xfalse" ]; then
    echo "Running tests..."
    make test
fi

make dist
make distclean

#Create signature
gpg --detach-sign --default-key $KEYID $PACKAGE-$VERSION.tar.gz
gpg --verify $PACKAGE-$VERSION.tar.gz.sig

if [ "x$do_publish" != "xfalse" ]; then
    echo "Publishing artifacts..."
    git tag -u $KEYID -m $VERSION $PACKAGE-$VERSION
    git push --tags

    #Update gh-pages
    git checkout gh-pages
    mv $PACKAGE-$VERSION.tar.gz releases/
    mv $PACKAGE-$VERSION.tar.gz.sig releases/

    git add releases/$PACKAGE-$VERSION.tar.gz
    git add releases/$PACKAGE-$VERSION.tar.gz.sig

    versions=$(ls -1v releases/*.tar.gz | awk -F\- '{print $3}' | sed 's/\.tar\.gz//' | paste -sd ',' - | sed 's/,/, /g' | sed 's/\([0-9.]\{1,\}\)/"\1"/g')
    sed -i -e "2s/\[.*\]/[$versions]/" releases.html
    git add releases.html

    git commit -m "Added tarball for release $VERSION"
    git push
    git checkout master
fi

echo "Success!"
