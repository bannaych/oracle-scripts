#!/bin/bash
# Script to promote Disaster Recovery server using Active-DR
# Version 0.1
#

# Set variables

JsonContent="Content-Type: application/json"
ApiToken=aa009fd2-7686-7d48-8698-26b7eb2ae841
Cookie=/tmp/cookie.jar
MaxTimeout=30
Array1=10.226.224.112
Curl=/usr/bin/curl
tput clear

#
# Funtion to Stop Oracle Grid infrastructure
#

stop_grid ()
{

    DB_HOME=/u01/app/oracle/product/19c/dbhome_1
    GRID_HOME=/u01/app/grid
    export ORACLE_SID=+ASM
    export ORACLE_HOME=$GRID_HOME
    export PATH=$PATH:$HOME/.local/bin:$ORACLE_HOME/bin

    echo "Unounting Diskgroups DATA and FRA..."
           asmcmd umount DATA
           asmcmd umount FRA
}

#
# Funtion to Start Oracle Grid infrastructure
#

start_grid ()
{

    DB_HOME=/u01/app/oracle/product/19c/dbhome_1
    GRID_HOME=/u01/app/grid
    export ORACLE_SID=+ASM
    export ORACLE_HOME=$GRID_HOME
    export PATH=$PATH:$HOME/.local/bin:$ORACLE_HOME/bin

    echo "Mounting Diskgroups DATA and FRA..."
           asmcmd mount DATA
           asmcmd mount FRA
}

#
# Funtion to Stop the  Oracle database
#

stop_ora ()
{


    ORACLE_SID=orcl
    ORACLE_BASE=/u01/app/oracle
    ORACLE_HOME=$ORACLE_BASE/product/19c/dbhome_1
    PATH=$PATH:$HOME/.local/bin:$HOME/bin:$ORACLE_HOME/bin
    export PATH ORACLE_SID ORACLE_BASE ORACLE_HOME

    sleep 2
    echo "Shutting Down Oracle Database"
    echo "shutdown immediate" | sqlplus -s / as sysdba
}

#
# Funtion to Start the  Oracle database
#
start_ora ()
{

    ORACLE_SID=orcl
    ORACLE_BASE=/u01/app/oracle
    ORACLE_HOME=$ORACLE_BASE/product/19c/dbhome_1
    PATH=$PATH:$HOME/.local/bin:$HOME/bin:$ORACLE_HOME/bin
    export PATH ORACLE_SID ORACLE_BASE ORACLE_HOME

    sleep 2
    echo "Starting Oracle Database"
    echo "startup" | sqlplus -s / as sysdba
}

#
# Funtion to Authenticate against the DR array
#

auth ()
{

    ${Curl} -s -k -m ${MaxTimeout} -H "${JsonContent}" -c ${Cookie} -X POST https://${Array1}/api/1.17/auth/session -d "
    {
            \"api_token\": \"${ApiToken}\"
    }
    "  >/dev/null
}

#
# Funtion to promte the DR POD
#

promote_dr ()
{
    echo ""
    echo "Initiating Promotion of DR POD ora-target..."
    echo
    ${Curl} -s -k -m ${MaxTimeout} -H "${JsonContent}" -b ${Cookie} -X PUT https://${Array1}/api/1.19/pod/ora-target -d "
    {
             \"requested_promotion_state\": \"promoted\"

    }
    " >/dev/null
}

#
# Funtion to demote the DR POD
#

demote_dr ()
{
    echo ""
    echo "Initiating demotion of DR POD ora-target..."
    echo
    ${Curl} -s -k -m ${MaxTimeout} -H "${JsonContent}" -b ${Cookie} -X PUT https://${Array1}/api/1.19/pod/ora-target -d "
    {
             \"requested_promotion_state\": \"demoted\"

    }
    " >/dev/null
}

#
# Funtion to remote the undo-demote pod on DR
#
remove_undo ()
{
    echo ""
    echo "Removing ora-target.undo-demote ..."
    echo
    ${Curl} -s -k -m ${MaxTimeout} -H "${JsonContent}" -b ${Cookie} -X DELETE https://${Array1}/api/1.19/pod/ora-target.undo-demote -d "
    {
             \"eradicate\": true

    }
    " >/dev/null
}

#
# Funtion check the status of POD
#

stats ()
{
    ${Curl} -s -k -m ${MaxTimeout} -H "${JsonContent}" -b ${Cookie} -X GET https://${Array1}/api/1.19/pod/ora-target|awk -F, '{print $11}'
}

auth

#
# Funtion check the status of POD
#

check_status ()
{
    STATUS="$(stats|awk -F: '{print $2}')"
    #stats
    while [ ${STATUS:2:-1} != "promoted" ]
        do
         STATUS="$(stats|awk -F: '{print $2}')"
         tput cup 3 0
         echo "Checking POD status $STATUS...."
         sleep 5
    done
}




if [ ${#} -eq 1 ]
then
        case ${1} in
        promote)

            promote_dr
            sleep 1
            check_status
            sleep 1
            start_grid
            start_ora;;

        demote)
            auth
            remove_undo
            sleep 1
            stop_ora
            sleep 1
            stop_grid
            sleep 1
            demote_dr;;

        status)
           source ./view.sh;;
        *)
             echo "Error: USAGE: switch-dr.sh start|stop"
        esac
fi
