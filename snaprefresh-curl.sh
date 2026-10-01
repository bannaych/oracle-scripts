#!/bin/bash
# Chris Bannayan
# Version 4.0
# Set variables

JsonContent="Content-Type: application/json"
XmlContent="Content-Type: application/xml"
ApiToken=1234567899
Cookie=/tmp/cookie.jar

MaxTimeout=30
Array=10.226.224.112
SourceVol=cbora1-data
SourceVol1=cbora1-fra
TargetVol=cbora2-data
TargetVol1=cbora2-fra
Suffix=`date +%s`
PGROUP=asmora
SNAPDIR=$PWD/snapdir
DB_HOME=/u01/app/oracle/product/19c/dbhome_1
GRID_HOME=/u01/app/grid
Curl=/usr/bin/curl
SNAPDIR="/home/oracle/snapdir"
BOLD=$(tput bold)
NORMAL=$(tput sgr0)


#if [ -d $SNAPDIR ]
#  then continue
#else
#  mkdir $SNAPDIR
#fi

#G
# Fuction to Stop Oracle Grid
#
start=`date`
echo $start >> $SNAPDIR/start-time
grid_stop ()
{

export ORACLE_SID=+ASM
export ORACLE_HOME=$GRID_HOME
export PATH="$ORACLE_HOME/bin:$PATH"

"$GRID_HOME/bin/sqlplus" -s / as sysasm <<'EOF'
whenever sqlerror exit 1
alter diskgroup DATA dismount force;
alter diskgroup FRA  dismount force;
exit;
EOF
}


#
# Fuction to Start Oracle Grid
#

grid_start ()
{

export ORACLE_SID=+ASM
export ORACLE_HOME=$GRID_HOME
export PATH="$ORACLE_HOME/bin:$PATH"

"$GRID_HOME/bin/sqlplus" -s / as sysasm <<'EOF'
whenever sqlerror exit 1
alter diskgroup DATA mount force;
alter diskgroup FRA  mount force;
exit;
EOF
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
echo "Shutting Down Oracle Database...."
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
                \"asmora\"
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

echo -e "${GREEN}\nOverwriting Target Volumes ${TargetVol} and ${TargetVol1} with Source Sanpshots... ${NC}"
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

echo "=========================================="
echo $BOLD"Step 1 - Stopping ORACLE..."$NORMAL
echo "========================================="
echo ""
stop_ora
sleep 2
echo ""
echo "=========================================="
echo $BOLD"Step 2 - Stopping ASM...."$NORMAL
echo " =========================================="
echo ""
grid_stop
sleep 2
auth
echo "===================================================="
echo $BOLD"Step 3 - Taking Protection Group Snapshot...."$NORMAL
echo "===================================================="
pgroup
echo "===================================================="
echo  $BOLD"Step 4 - Refreshing Target Volumes...."$NORMAL
echo "===================================================="
volumes
echo ""
sleep 2
echo "===================================================="
echo $BOLD "Step 5 - Starting ASM...."$NORMAL
echo "===================================================="
echo ""
grid_start
sleep 2
echo "===================================================="
echo  $BOLD"Step 6 - Starting ORACLE..."$NORMAL
echo "===================================================="
start_ora
echo " "
echo " "
echo "===================================================="
echo  $BOLD"Database Refresh Complete..."$NORMAL
echo "===================================================="
end=`date`
echo $end >> $SNAPDIR/end-time
paste $SNAPDIR/start-time $SNAPDIR/end-time > $SNAPDIR/complete
