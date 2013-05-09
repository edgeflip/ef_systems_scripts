#!/bin/bash

set -e

SCRIPT_DIR="$( cd "$( dirname "$0" )" && pwd )"
. ${SCRIPT_DIR}/../functions.sh

PACKAGE='mockclient'
DEST_DIR=$PACKAGE
REPODIR='git@github.com:edgeflip/mockclient.git'
HOMEPAGE='http://fill.me.in'
DESCRIPTION='(Edgeflip) Edgeflip mock client app'
REQUIREMENTS='requirements.txt'
BASE_DIR=/var/www

check_args $1 $2

cd $BASE_DIR

clone_app
cd $DEST_DIR
checkout_tag
add_appinfo
clean_git
build_python

build_package
#include_in_botbuilds
