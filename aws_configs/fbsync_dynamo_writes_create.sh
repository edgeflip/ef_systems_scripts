#!/bin/bash

set -e # bail on any failures


# Fill this out
AS="eflip-production-fbsync-dynamo-writes-as"
LC="eflip-production-64-fbsync-dynamo-writes"
ELB="eflip-production-fbsync-dynamo-writes"
AMI="ami-d9d6a6b0"
SG="edgeflip-ec2-sg"
SIZE="m3.medium"
CONFIG="/home/tristan/src/ef_systems_scripts/aws_configs/fbsync_dynamo_writes_launch_config"
APP="edgeflip-fbsync"
APPENV="production"



##############################
## LAUNCH CONFIG CREATION
as-create-launch-config ${LC} --key edgeflip_052613 --image-id ${AMI} --instance-type ${SIZE} \
        --user-data-file ${CONFIG} --group ${SG}

##############################
## AUTOSCALE GROUP CREATION
as-create-auto-scaling-group ${AS} --launch-configuration ${LC} \
        --availability-zones us-east-1c --min-size 0 --max-size 0 \
        --tag "k=env,v=${APPENV},p=true" --tag "k=app,v=${APP},p=true"

as-update-auto-scaling-group ${AS} --max-size 1 --min-size 1 --desired-capacity 1
