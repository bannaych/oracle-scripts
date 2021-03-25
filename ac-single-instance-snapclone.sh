#!/bin/bash
# Chris Bannayan
# Version 1.0
# This script will automate the refreshing a single instance Oracle Database running on ActiveCluster
#
#

JsonContent="Content-Type: application/json"
XmlContent="Content-Type: application/xml"
ApiTokenFA1=476d58bc-3c91-0d10-1b9e-0f31058c4621
ApiTokenFA2=8e2d8f2e-6302-3c3d-5e1e-78cfa6f09583
Cookie=/tmp/cookie.jar

MaxTimeout=30
Array1=192.168.111.130
Array2=192.168.111.133
SourceVol=zz-ora-ac-u01
SourceVol1=zz-ora-ac-u02
TargetVol=cb-ora-dr::ora-ac-u01-dr
TargetVol1=cb-ora-dr::ora-ac-u02-dr
Suffix=`date +%s`
PGROUP=cb-ora::oraac-pg
SNAPDIR=$PWD/snapdir
Curl=/usr/bin/curl



#source ./ac.sh




#
# Fuction to Start Oracle Grid
#


#
# Fuction to Stop Oracle Database
#

stop_ora ()
{
echo " "
export ORACLE_BASE=/u01/app/oracle
export ORACLE_HOME=$ORACLE_BASE/product/19.0.0/dbhome_1
export ORA_INVENTORY=/u01/app/oraInventory
export ORACLE_SID=orcl
export PATH=$PATH:$ORACLE_HOME/bin
echo "  Shutting Down Oracle Database..."
echo "shutdown immediate" | sqlplus -s / as sysdba

}

#
# function to start Oracle Database
#

start_ora ()
{
echo " "
export ORACLE_BASE=/u01/app/oracle
export ORACLE_HOME=$ORACLE_BASE/product/19.0.0/dbhome_1
export ORA_INVENTORY=/u01/app/oraInventory
export ORACLE_SID=orcl
export PATH=$PATH:$ORACLE_HOME/bin
echo "  Starting Oracle Database..."
echo "startup" | sqlplus -s / as sysdba
}

#
# funtion to unmount filesystems
#

umount_fs ()
{
MOUNT=/u01
MOUNT1=/u02

if grep -qs $MOUNT $MOUNT1 /proc/mounts
 then
   echo "  $MOUNT and $MOUNT1 are still mounted."
   echo "  Unmounting $MOUNT and $MOUNT1...."
   echo " "
   sudo umount -l $MOUNT
   sudo umount -l $MOUNT1
fi
}

#
# function to mount filesystems
#
mount_fs ()
{
MOUNT=/u01
MOUNT1=/u02

echo "  Mounting Filesystems $MOUNT and $MOUNT1..."
echo " "
  sudo mount -l $MOUNT
  sudo mount -l $MOUNT1
}

#
# funtion to authenticate to the FlashArray
#

auth ()
{

${Curl} -s -k -m ${MaxTimeout} -H "${JsonContent}" -c ${Cookie} -X POST https://${Array1}/api/1.17/auth/session -d "
{
        \"api_token\": \"${ApiTokenFA1}\"
}
"  >/dev/null
}

auth1 ()
{

${Curl} -s -k -m ${MaxTimeout} -H "${JsonContent}" -c ${Cookie} -X POST https://${Array2}/api/1.17/auth/session -d "
{
        \"api_token\": \"${ApiTokenFA2}\"
}
"  >/dev/null
}

#
# Function to create the protection group snapshots
#

pgroup ()
{
${Curl} -s -k -m ${MaxTimeout} -H "${JsonContent}" -b ${Cookie} -X POST https://${Array1}/api/1.17/pgroup -d "
{
        \"apply_retention\": true,
        \"snap\": true,
        \"source\": [
                \"cb-ora::oraac-pg\"
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

echo -e "  Overwriting Target Volumes with Source Sanpshots "
${Curl} -s -k -m ${MaxTimeout} -H "${JsonContent}" -b ${Cookie} -X POST https://${Array2}/api/1.17/volume/${TargetVol} -d "
{
        \"source\": \"${PGROUP}.SNAP-${Suffix}.${SourceVol}\",
        \"overwrite\": true
}
"  >/dev/null

${Curl} -s -k -m ${MaxTimeout} -H "${JsonContent}" -b ${Cookie} -X POST https://${Array2}/api/1.17/volume/${TargetVol1} -d "
{
        \"source\": \"${PGROUP}.SNAP-${Suffix}.${SourceVol1}\",
        \"overwrite\": true
}
"  >/dev/null
}

stop_ora
sleep 2
umount_fs
sleep 2
auth
pgroup
sleep 2
auth1
volumes
sleep 2
mount_fs
sleep 2
