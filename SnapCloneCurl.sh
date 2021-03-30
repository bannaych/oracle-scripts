#!/bin/bash
# Chris Bannayan
# Version 4.0
# Set variables

JsonContent="Content-Type: application/json"
XmlContent="Content-Type: application/xml"
ApiToken=aa009fd2-7686-7d48-8698-26b7eb2ae841
Cookie=/tmp/cookie.jar

MaxTimeout=30
Array=10.226.224.112
SourceVol=cbora1-data
SourceVol1=cbora1-fra
TargetVol=cbora2-data
TargetVol1=cbora2-fra
Suffix=`date +%s`
PGROUP=cbora
SNAPDIR=$PWD/snapdir
DB_HOME=/u01/app/oracle/product/19c/dbhome_1
GRID_HOME=/u01/app/grid
Curl=/usr/bin/curl


#if [ -d $SNAPDIR ]
#  then continue
#else
#  mkdir $SNAPDIR
#fi

#
# Fuction to Stop Oracle Grid
#

grid_stop ()
{

export ORACLE_SID=+ASM
export ORACLE_HOME=$GRID_HOME
export PATH=$PATH:$HOME/.local/bin:$ORACLE_HOME/bin

        echo "About to unmount ASM disk groups +DATA & +FRA"
        echo "alter diskgroup DATA dismount force;" | sqlplus -s / as sysasm
        echo "alter diskgroup FRA dismount force ;" | sqlplus -s / as sysasm
}


#
# Fuction to Start Oracle Grid
#

grid_start ()
{

export ORACLE_SID=+ASM
export ORACLE_HOME=$GRID_HOME
export PATH=$PATH:$HOME/.local/bin:$ORACLE_HOME/bin

        echo "About to unmount ASM disk groups +DATA & +FRA"
        echo "alter diskgroup DATA mount;" | sqlplus -s / as sysasm
        echo "alter diskgroup FRA mount ;" | sqlplus -s / as sysasm
}

#
# Fuction to Stop Oracle Database
#

stop_ora ()
{
export ORACLE_SID=orcl
export ORACLE_HOME=$DB_HOME
export PATH=$PATH:$ORACLE_HOME/bin
sleep 2
echo "Shutting Down Oracle Database"
echo "shutdown immediate" | sqlplus -s / as sysdba
}

#
# function to start Oracle Database
#

start_ora ()
{
export ORACLE_SID=orcl
export ORACLE_HOME=$DB_HOME
export PATH=$PATH:$ORACLE_HOME/bin
sleep 2
echo "Starting Oracle Database"
echo "startup" | sqlplus -s / as sysdba
}

#
# funtion to change DB name
#


db_name_change ()
{
export ORACLE_SID=orcl
export ORACLE_HOME=$DB_HOME
export PATH=$PATH:$ORACLE_HOME/bin

echo -e "Rename Database ${ORACLE_SID} as testdb "

nid target=sys/passwd dbname=testdb logfile=dbnamechg.log setname='YES'
}

#
# funtion to authenticate to the FlashArray
#

auth ()
{

${Curl} -s -k -m ${MaxTimeout} -H "${JsonContent}" -c ${Cookie} -X POST https://${Array}/api/1.17/auth/session -d "
{
        \"api_token\": \"${ApiToken}\"
}
"  >/dev/null
}


#
# Function to create the protection group snapshots
#

pgroup ()
{
${Curl} -s -k -m ${MaxTimeout} -H "${JsonContent}" -b ${Cookie} -X POST https://${Array}/api/1.17/pgroup -d "
{
        \"apply_retention\": true,
        \"snap\": true,
        \"source\": [
                \"cbora\"
        ],
        \"suffix\": \"SNAP-${Suffix}\"
}
" >/dev/null
}



#
# funtion to refresh the target volumes with the snapshots from the source
#

volumes ()
{

echo -e "${GREEN}\nOverwriting Target Volumes with Source Sanpshots ${NC}"
${Curl} -s -k -m ${MaxTimeout} -H "${JsonContent}" -b ${Cookie} -X POST https://${Array}/api/1.17/volume/${TargetVol} -d "
{
        \"source\": \"${PGROUP}.SNAP-${Suffix}.${SourceVol}\",
        \"overwrite\": true
}
"  >/dev/null

${Curl} -s -k -m ${MaxTimeout} -H "${JsonContent}" -b ${Cookie} -X POST https://${Array}/api/1.17/volume/${TargetVol1} -d "
{
        \"source\": \"${PGROUP}.SNAP-${Suffix}.${SourceVol1}\",
        \"overwrite\": true
}
"  >/dev/null
}

echo "STOPPING ORACLE..."
stop_ora
sleep 2
echo "STOPPING ASM...."
grid_stop
sleep 2
auth
pgroup
volumes
sleep 2
echo "STARTING ASM...."
grid_start
sleep 2
echo "STARTING ORACLE..."
start_ora
