#!/bin/bash

# Deploy script  #################################


############################
# SYNTAX CHECK
# - Check that we have the right # of options, offer help
REQUIREDARGS=3
NUMOFARGS=$#
NEWRELIC_USER=Jenkins
JENKINS_AWSHOME=/home/ubuntu/
FABFILE=${JENKINS_AWSHOME}/fabfile.py
ID_RSA_FILE="ef_deploy_id_rsa"

# Source the other vars
. /etc/environment

show_usage() {
        echo " =================== ";echo " ";
        echo " Syntax "
        echo " ./deploy.sh APP ENV NEW_VERSION"
        echo " "
        echo " Example:
                 deploy.sh edgeflipcelery staging v1.0.3"
        echo " YOUR SUPPLIED ARGS were:"
        echo "    APP NAME - $APP_NAME"
        echo "    APP ENVIRONMENT - $APP_ENV"
        echo "    NEW VERSION - $NEW_VERSION";echo " ";
        echo " ======================"
        exit 0
}

check_your_syntax() {
        # Check if you are asking for halp
        if [ "$1" = "-h" ] || [ "$1" = "--help" ]
                then
                show_usage
                exit 0
        fi
        if [ $NUMOFARGS -lt $REQUIREDARGS ]
                then
                echo "`date` -- ERROR, $REQUIREDARGS arguments required and $NUMOFARGS is an invalid number of args"
                show_usage
        fi
}

####################################
## OPTIONS AND VARIABLES
APP_NAME=$1    # - APP_NAME ie narwhal
APP_ENV=$2     # - APP_ENV ie staging
NEW_VERSION=$3 # - NEW_VERSION is the new version #
RANDOM_STRING=`date +%s%m%d%SS|sed 's/ //g'`
APPENVNAME="$APP_NAME`echo '-'`$APP_ENV"   # -APPENVNAME is the appname-env tag
# Set newrelic app location
newrelic=$JENKINS_AWSHOME/newrelic.sh
# Temp files
export DEPLOYTMP=${JENKINS_AWSHOME}/temp/deploy.$RANDOM_STRING.$APPENVNAME.tmp
if [ -s $DEPLOYTMP ] > /dev/null;then rm $DEPLOYTMP;fi
export VERSIONREPORT=${JENKINS_AWSHOME}/temp/deploy.$RANDOM_STRING.$APPENVNAME.version
if [ -s $VERSIONREPORT ] > /dev/null;then rm $VERSIONREPORT;fi

# set defaults for app options
NEWRELIC_ENABLED=0        # Should we try to run the newrelic deployment
NEWRELIC_APP="NONE"       # The correctly formatted Name - Env Newrelic app name
FABRIC_ALIAS="NONE"       # The string you use for fab for this app-env
KICK_TYPE="parallel"      # How safe and slow should we kick?  Options: parallel, normal, rolling
APT_NAME="NONE"           # The string you use for the reprepro and aptitude steps
REPO_NAME="NONE"          # The browser address to the repo, used for the diff generate

## END OF VARS
#########################################



########################
## FUNCTIONS

error_check() {
    if [ $RETURN_CODE -ne 0 ]
        then
        echo "`date` -- Error encountered during $PROGSTEP : $RETURN_CODE"
        fi
    }

check_current_version() {
        export PROGSTEP="check_current_version - Builder check"
        echo " "
        echo "#################################"
        echo "`date` -- Checking builder versions for $APPENVNAME"
        cd /mnt/packages
        reprepro ls $APP_NAME
                RETURN_CODE=$?;error_check

        export PROGSTEP="check_current_version - Fab version check"
        echo " "
        echo "#################################"
        echo "`date` -- Checking fab versions for $APPENVNAME"
        fab -f ${FABFILE} -i ${JENKINS_AWSHOME}/${ID_RSA_FILE} -u ubuntu -D -w -P -R $FABRIC_ALIAS -- "sudo aptitude show $APP_NAME" | grep Version |awk '{print $4}' | sed 's/-1//g' | head -n1 > $DEPLOYTMP 2>/dev/null
                RETURN_CODE=$?;error_check

        APP_CURRENT_VERSION=`cat $DEPLOYTMP | sed 's/ //g'|sed 's/v//g'`
        OLD_VERSION="v`echo $APP_CURRENT_VERSION`"
        echo "Old version we saw on $APPENVNAME nodes: $OLD_VERSION"
        echo "New version: $NEW_VERSION"
    }

build_new_version() {
    export PROGSTEP="Build new version"
    if [ "$APP_ENV" = "staging" ]
        then
        BUILD_STATUS=1
        until [ ${BUILD_STATUS} -eq 0 ]
            do
            echo " "
            echo "#################################"
            echo "`date` -- Building $APP_NAME $NEW_VERSION jenkins"
            cd /home/ubuntu
            ./build/$APP_NAME/build_full.sh $NEW_VERSION 2>&1 | tee $DEPLOYTMP
                    RETURN_CODE=$?;error_check

            if [ ${RETURN_CODE} -ne 0 ]
                then
                if grep "npm ERR" $DEPLOYTMP > /dev/null
                    then
                    echo "`date` -- NPM failed us!  We're trying again"
                    BUILD_STATUS=1
                else
                    echo "`date` -- Build failed for $APPENVNAME $NEW_VERSION"
                    exit 1
                fi
            else
                echo "`date` -- Completed building $APP_NAME $NEW_VERSION jenkins with a $RETURN_CODE"
                BUILD_STATUS=0
            fi
        done

    fi
    }

include_in_repo() {
    if [ "$APP_ENV" = "staging" ]
        then
        export PROGSTEP="Include new version in staging repo"
        echo " "
        echo "#################################"
        echo "`date` -- $PROGSTEP"
        cd /mnt/packages
        reprepro includedeb staging /mnt/builds/`ls -lart /mnt/builds|grep .deb|grep $APP_NAME|tail -n1|awk '{print $9}'`
                RETURN_CODE=$?;error_check
        echo "`date` -- Completed including $NEW_VERSION in staging repo for $APP_NAME with $RETURN_CODE"
        fi

    if [ "$APP_ENV" = "production" ]
        then
        #export PROGSTEP="Include old version in backoutprod repo"
        #echo " "
        #echo "#################################"
        #echo "`date` -- $PROGSTEP"
        #cd /mnt/packages
        #reprepro copy backoutprecise precise $APP_NAME
                #RETURN_CODE=$?;error_check
        #echo "`date` -- $APP_NAME $OLD_VERSION put into backoutprecise repo with $RETURN_CODE"

        export PROGSTEP="Include new version in prod repo"
        echo " "
        echo "#################################"
        echo "`date` -- $PROGSTEP"
        cd /mnt/packages
        reprepro copy precise staging $APP_NAME
                RETURN_CODE=$?;error_check
        echo "`date` -- $APP_NAME $NEW_VERSION copied from staging to prod repo with $RETURN_CODE"
    fi
    }

sync_the_repo() {
        export PROGSTEP="sync_repo - jenkins"
        echo " "
        echo "#################################"
        echo "`date` -- Syncing apt-repo on jenkins"

        cd /mnt/packages
        ./sync_repo.sh
            RETURN_CODE=$?;error_check
        echo "`date` -- Completed sync of apt-repo on jenkins with $RETURN_CODE"

        export PROGSTEP="sync_repo - geppetto"
        echo " "
        echo "#################################"
        echo "`date` -- Syncing apt-repo on geppetto"
        ssh -i /home/ubuntu/.aws/id_rsa ubuntu@geppetto.efprod.com -t "/home/ubuntu/pull-apt-repo.sh"
            RETURN_CODE=$?;error_check
        echo "`date` -- Completed sync of apt-repo on geppetto with $RETURN_CODE"
    }


kick_the_nodes() {
    if [ -s $DEPLOYTMP ] > /dev/null;then rm $DEPLOYTMP;fi
        echo " "
        echo "#################################"
        export PROGSTEP="Restarting Puppet on $APPENVNAME using a $KICK_TYPE kick."
        echo "`date` -- $PROGSTEP"
        case $KICK_TYPE in
                "parallel" )
                        fab -f ${FABFILE} -i ${JENKINS_AWSHOME}/${ID_RSA_FILE} -D -P -R $FABRIC_ALIAS kick
                                RETURN_CODE=$?;error_check
                        ;;

                "normal" )
                        fab -f ${FABFILE} -i ${JENKINS_AWSHOME}/${ID_RSA_FILE} -D -w -R $FABRIC_ALIAS kick
                                RETURN_CODE=$?;error_check
                        ;;

                "rolling" )
                        fab -f ${FABFILE} -i ${JENKINS_AWSHOME}/${ID_RSA_FILE} -D -w -R $FABRIC_ALIAS -- "sudo rm -rf /root/creds/app;sudo pkill -9 puppet;sudo service puppet restart;sleep 10" 2>&1 > $DEPLOYTMP
                                RETURN_CODE=$?;error_check
                        ;;
                esac

        echo "`date` -- Completed puppet kick with ${RETURN_CODE}"
        echo " "
        echo " "
        echo "#################################################"
        echo "You may want to head to loggins to watch your kick"
        echo "#################################################"
        echo " "
        echo " "
      if [ -s $DEPLOYTMP ] > /dev/null;then cat $DEPLOYTMP;fi

    }


new_version_check() {
        if [ -s $DEPLOYTMP ] > /dev/null;then rm $DEPLOYTMP;fi

        echo "`date` -- Sleeping for 30 seconds to allow nodes to get new version"
        sleep 30

        echo " "
        echo "#################################"
        export PROGSTEP="Checking versions for $."
        echo "`date` -- $PROGSTEP"
        fab -f ${FABFILE} -i ${JENKINS_AWSHOME}/${ID_RSA_FILE} -D -w -P -R $FABRIC_ALIAS -- "sudo aptitude show `echo $APP_NAME`"|grep Version |tee $VERSIONREPORT 2> $DEPLOYTMP
                RETURN_CODE=$?;error_check

        if grep ${APP_CURRENT_VERSION} ${VERSIONREPORT} > /dev/null
            then
            echo " ";echo " "
            echo "`date` --  ALERT, OLD VERSION STILL DETECTED ON $APP_NAME IN $APP_ENV"
            exit 1
        fi
    }

newrelic_deploy() {
        export PROGSTEP="New Relic deployment";
        echo " "
        echo "#################################"
        echo "`date` -- $PROGSTEP"
        ${newrelic} "$NEWRELIC_APP" "$NEW_VERSION" "$NEW_VERSION"
                RETURN_CODE=$?;error_check
}

## END OF FUNCTIONS
##################################



###################################
## app settings

case $APPENVNAME in
    edgeflipcelery-production )
        NEWRELIC_ENABLED=1
        NEWRELIC_APP="edgeflipcelery-production"
        FABRIC_ALIAS="edgeflipcelery-production"
        APT_NAME="edgeflipcelery"
        REPO_NAME="edgeflip"
        KICK_TYPE="rolling"      # How safe and slow should we kick?  Options: parallel, normal, rolling
        ;;

    edgeflipcelery-staging )
        NEWRELIC_ENABLED=1
        NEWRELIC_APP="edgeflipcelery-staging"
        FABRIC_ALIAS="edgeflipcelery-staging"
        APT_NAME="edgeflipcelery"
        REPO_NAME="edgeflip"
        KICK_TYPE="parallel"      # How safe and slow should we kick?  Options: parallel, normal, rolling
        ;;

    edgeflip-production )
        NEWRELIC_ENABLED=1
        NEWRELIC_APP="edgeflip-production"
        FABRIC_ALIAS="edgeflip-production"
        APT_NAME="edgeflip"
        REPO_NAME="edgeflip"
        KICK_TYPE="rolling"      # How safe and slow should we kick?  Options: parallel, normal, rolling
        ;;

    edgeflip-staging )
        NEWRELIC_ENABLED=1
        NEWRELIC_APP="edgeflip-staging"
        FABRIC_ALIAS="edgeflip-staging"
        APT_NAME="edgeflip"
        REPO_NAME="edgeflip"
        KICK_TYPE="parallel"      # How safe and slow should we kick?  Options: parallel, normal, rolling
        ;;

        * )
        echo "`date` -- ERROR DETERMINING YOUR TARGET"
        echo " "
        show_usage
        exit 0
        ;;

        esac

## END OF APP SETTINGS
######################################

#######################################
## MAIN PROGRAM
echo "`date` -- Deployment for $APPENVNAME $NEW_VERSION started"

check_current_version
build_new_version
include_in_repo
sync_the_repo
kick_the_nodes
if [ $NEWRELIC_ENABLED -eq 1 ]
        then
        newrelic_deploy
fi
new_version_check
echo "`date` -- Completed deployment for $APPENVNAME $NEW_VERSION"
rm -rf ${DEPLOYTMP}
rm -rf ${VERSIONREPORT}