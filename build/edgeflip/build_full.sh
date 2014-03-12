#!/bin/bash

set -e

SCRIPT_DIR="$( cd "$( dirname "$0" )" && pwd )"
. ${SCRIPT_DIR}/../functions.sh

PACKAGE='edgeflip'
DEST_DIR=$PACKAGE
REPODIR='git@github.com:edgeflip/edgeflip.git'
HOMEPAGE='http://fill.me.in'
DESCRIPTION='(Edgeflip) Edgeflip app'
REQUIREMENTS='/var/www/edgeflip/requirements/base.requirements'
BASE_DIR=/var/www
export WORKON_HOME=/var/www/edgeflip/.virtualenv
check_args $1 $2

cd $BASE_DIR

clone_app
cd $DEST_DIR
checkout_tag
add_appinfo
clean_git
build_python_app

build_package