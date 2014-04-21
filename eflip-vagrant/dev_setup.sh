#!/usr/bin/env bash
export MYSQL_PWD=root
git clone git@github.com:edgeflip/edgeflip.git
export DEBIAN_FRONTEND=noninteractive 
cd edgeflip 
fab build 
