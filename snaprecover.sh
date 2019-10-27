#!/usr/bin/bash
#
# Script to recover and Oracle database using Pure Storage Snapshots
# Ver: 0.1
# Chris Bannayan




FA1="192.168.111.130"
USER="pureuser"
LOGFILE=log
SUFFIX=$1

if [ $# -ne 1 ]
then
  echo $0: usage: snaprecover suffix
  exit 1
fi


checkora ()
{
  ps -ef | grep ora_pmon|grep -v grep
   ERR=$?
     if [ $ERR = 1 ]
       then
       echo "ORACLE DB has been Shutdown "
     else
       echo "Oracle DB Still not shutdown "
       exit 0
     fi
}

shut ()
{
 echo "shutdown immediate" | sqlplus -s / as sysdba
 checkora
}


start ()
{
 echo "startup" | sqlplus -s / as sysdba
}


log() {
        D=`date +%H:%M:%S`
        echo $D - $*
        echo "---------------------------" >> $LOGFILE
        echo $D - $* >> $LOGFILE
}

clear

echo "About to take snaphot of primary volumes using the following command"
echo "purevol snap --suffix $SUFFIX ora3-data ora3-fra"
read ans
ssh $USER@$FA1 'purevol snap --suffix '$SUFFIX' ora3-data ora3-fra'

#echo "drop table t5;" | sqlplus -s / as sysdba > /dev/null

# Modify Some Data
echo "Snapshot taken so now we will modify some data to generate some redo, Press return to proceed"
read ans

sqlplus -s / as sysdba @create.sql

echo "About to shutdown orcl DB on ora3 so that we can simulate the loss of the USERS datafile, press return to proceed"
read ans

#echo "shutdown immediate" | sqlplus -s / as sysdba
shut


echo "About to DELETE the USERS datafile to simulate a data loss or media corruption, press return to proceed"
read ans
rm  /u01/app/oracle/oradata/ORCL/datafile/o1_mf_users_gv7qdd22_.dbf
echo Datafile deleted
echo

echo "About to start orcl DB on ora3 after we have dropped the USERS datafile, Press return to proceed"
read me
#echo "startup " | sqlplus -s / as sysdba
start

echo "The orcl DB on ora3 is broken at this point and we need a restore, instead of waiting hours for an RMAN restore lets do it instantly f
rom the snapshot instead"
echo "First we'll shutdown abort the TARGETDB instance, Press return to proceed"
read ans

echo "shutdown abort" | sqlplus -s / as sysdba
echo
echo "Now we're going to restore a snapshot of the DATA disk only, we need to preserve the CONTROL_REDO and FRA Filesystems as they contain the redo we need for recovery"
echo
echo "About to unmount the /u01 filesystem Press return to proceed"
read ans

sudo umount -l /u01
sleep 1
echo "/u01 is now unmounted"
echo
echo "About to restore orcl DB on ora3 data volume using the snaphot using the following commands"
echo "purevol copy --overwrite ora3-data.$SUFFIX ora3-data"

read me
ssh $USER@$FA1 'purevol copy --overwrite ora3-data.'$SUFFIX' ora3-data '
echo
echo "About to mount /u01 filesystem, press return to proceed"
read ans

sudo mount /u01
echo
echo "About to mount orcl DB and then use RMAN to complete a point in time recovery to save the data modified since the snapshot"
echo "Press return to proceed"


echo "startup mount" | sqlplus -s / as sysdba

echo "recover database;" | rman target / nocatalog
echo "shutdown abort" | sqlplus -s / as sysdba
#echo "startup" | sqlplus -s / as sysdba
start

echo "select * from t5;" | sqlplus -s / as sysdba
echo
echo "------------------------------------------------------------------------------"
echo "                                                                              "
echo "   D A T A B A S E     R E C O V E R Y    C O M P L E T E                     "
echo "                                                                              "
echo "------------------------------------------------------------------------------"