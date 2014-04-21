#!/usr/bin/env bash
export MYSQL_ROOT_PW=root
git clone git@github.com:edgeflip/edgeflip.git
export DEBIAN_FRONTEND=noninteractive 
cd edgeflip 
fab build 
