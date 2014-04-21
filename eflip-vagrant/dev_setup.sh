#!/usr/bin/env bash
export MYSQL_ROOT_PW=root
git clone git@github.com:f4nt/edgeflip.git
export DEBIAN_FRONTEND=noninteractive 
cd edgeflip 
fab build 
