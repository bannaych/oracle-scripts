#!/bin/bash
# script:   Snapclone.sh - refresh oracle databases using Pure Storge Snapshots
# Author:   Chris Bannayan
# Date:     25/06/2017
# Rev:      0.8
# Platform: Unix,Linux


#
# Define Bold and non-bold screen output
#

BOLD=`tput smso`
NORM=`tput rmso`
SNAPDIR=$PWD/snapdir

# Define the Arrays and Users to connect to
# Sydney Lab

FA1="192.168.111.130"
USER="pureuser"
PGROUP=orapg


# Define the Targeet Volume to refresh
VOLTARGETDATA="ora2-data"
VOLTARGETFRA="ora2-fra"
# Define htre Primary volume to take snapshots from
VOLPRIMDATA="ora1-data"
VOLPRIMFRA="ora1-fra"



# Setup Grid Evironment


oracle ()
{
ORACLE_BASE=/u01/app/oracle
ORACLE_HOME=$ORACLE_BASE/product/oracle19.3/dbhome_1
ORACLE_SID=orcl
PATH=$PATH:$HOME/.local/bin:$HOME/bin:$ORACLE_HOME/bin
export ORACLE_BASE ORACLE_HOME ORACLE_SID PATH

}



# logfile function
# LOGFILE="snap.log"

log_note ()
{
        echo "`date +%d/%m/%y--%H:%M`" $* >> /home/oracle/scripts/pure.log
}

if [ -d $SNAPDIR ]
  then continue
else
  mkdir $SNAPDIR
fi


check_fs ()
{
MOUNT=/u01
MOUNT1=/u02

if grep -qs $MOUNT $MOUNT1 /proc/mounts
 then
   echo "$MOUNT and $MOUNT1 are still mounted."
   exit 0
 else
   echo "$MOUNT and $MOUNT1 are not mounted."
fi
}

check_fs1 ()
{
MOUNT=/u01
MOUNT1=/u02

if grep -qs $MOUNT $MOUNT1 /proc/mounts
 then
   echo "$MOUNT and $MOUNT1 have been mounted."
 else
   echo "$MOUNT and $MOUNT1 Still not mounted."
fi
}

RC ()
{
 ERR=$?
   if [ $ERR = 0 ]    
       then 
       echo "Data Insert successfull"
     else
       echo "Error adding data"
       exit 0
     fi
}

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


pgroup ()
{

PGROUP="orapg"

#
# Main loop to create the protection group snap
#
echo ""

      ssh $USER@$FA1 "for i in $PGROUP
             
             do 
               echo "======================================"
               purepgroup snap  \$i 
 done"
echo "Press Enter to continue: "
tput cup 11 25
read ans4
}

# Shutting down Oracle to apply snapshot refresh
#
start=`date` > $SNAPDIR/start-time
tput clear
tput cup 3 15
tput setaf 3
echo "PURE STORAGE ORACLE SNAPCLONE SCRIPT"
tput sgr0

tput cup 5 17
# Set reverse video mode
tput rev
echo "M A I N - M E N U"
tput sgr0
 
tput cup 7 15
echo "Source. ORA1 192.168.111.205"
 
tput cup 8 15
echo "Target. ORA2 192.168.111.206"
 
tput cup 10 15
echo "3. Enter Data in Source Database"

# Set bold mode 
tput bold
tput cup 12 15
read -p "Enter to continue " choice
 
#tput sgr0
#tput rc
tput sgr0

#tput cup 5 0
#echo " ============================================================="
#tput cup 7 0
#echo " |         Adding Data table called 'data' in source DB       |"
#echo " |         please enter a name and job title                  |"  
#echo " |         ie: chris SA                                       |"  
#tput cup 11 0
#echo " ============================================================="
#tput cup 13 0 
#echo " Enter Name and Job Title: "
#tput cup 13 27 
#read name job 
#echo
#echo "insert into t1 values ('$name', '$job');"|sqlplus sys/oracle@rac1:1521/orcl as sysdba > /dev/null
#echo "select * from  t1 where rowid=(select max(rowid) from t1);"|sqlplus sys/oracle@rac1:1521/orcl as sysdba 
#RC
#tput cup 32 0 
#echo "press Enter to continue: "
#tput cup 32 25 
#read ans2

tput clear
tput cup 3 15
tput setaf 3
echo "PROTECTION GROUP SNAPSHOT" 
tput sgr0
tput cup 5 15
echo "Do you want to take a Pgroup Snap Y/N: "
tput cup 5 55
read ans3
   case $ans3 in 
      y|Y) pgroup;;
      n|N) break;;
  esac





#
# Taking snapshot or source data
#


tput clear
tput cup 3 0
tput setaf 3
tput rev
echo " A B O U T   T O   S H U T D O W N   O R A C L E "
tput sgr0
tput cup 5 0 
echo "Press Enter To shutdown Oracle."
tput cup 5 32
read ans
oracle
tput cup 7 0
echo "Shutting down Oracle.."
tput cup 8 0
echo "shutdown immediate" | sqlplus -s / as sysdba
sleep 1
checkora
echo
sleep 2
tput cup 15 0
echo "$BOLD Unmounting the /u01 filesystem $NORM"
sudo umount -l /u01
tput cup 16 0
echo "$BOLD Unmounting the /u02 filesystem $NORM"
sudo umount -l /u02
sleep 1
check_fs
#


#
# ssh to the Pure array and get Volume snap listing
#
ssh $USER@$FA1 "purevol list --snap" > $SNAPDIR/snap.log
ssh $USER@$FA1 "purepgroup list --snap" > $SNAPDIR/snapgroup.log

#
# couple of loops to get Target and Primary volume and output them to a log file
# Get Listing on last 5 snapshots, then pick the snapshot to refresh with.
#


echo "${VOLTARGETDATA}" $'\n'"${VOLTARGETFRA}" > $SNAPDIR/snap1.log

awk '/orapg/ {print $1,$4,$5}' $SNAPDIR/snapgroup.log|head -5  > $SNAPDIR/snaps
printf "\n"
printf "Select from the following five Protection Groups Snapshots\n "
printf "==========================================="
printf "\n"

PS3="Please enter your choice: "
IFS=$'\n' read -d '' -r -a  options < $SNAPDIR/snaps

select opt in "${options[@]}" quit
do
case  $opt  in  
       $opt) echo $opt|awk '{print $1}'|tee $SNAPDIR/cb.log;break;;
       quit) exit 0;;

esac
done
for i in `cat $SNAPDIR/cb.log`; do grep $i $SNAPDIR/snap.log; done|awk '{print $1}'|head -2 >$SNAPDIR/new.log
cat $SNAPDIR/cb.log|awk '{print $1}' > $SNAPDIR/sn.log
paste  $SNAPDIR/new.log $SNAPDIR/snap1.log > $SNAPDIR/cb1.log

#
# Main loop to ssh into array and run the refresh
#

input="$SNAPDIR/cb1.log"

      echo "$BOLD Refreshing from latest $VOLPRIM snapshots `cat $SNAPDIR/cb1.log|awk '{print $1}'` ... $NORM"
      
      while IFS=" " read -r f1 f2 
         do ssh $USER@$FA1 purevol copy --overwrite "$f1" "$f2" </dev/null
      done < "$input"

echo "$BOLD Mounting /u01 filesystem $NORM"
sudo mount -l /u01
echo "$BOLD Mounting /u02 filesystem $NORM"
sudo mount -l /u02
sleep 2
check_fs1

oracle
echo "$BOLD Starting Oracle.... $NORM"
echo "startup" | sqlplus -s / as sysdba
#echo "alter system set db_unique_name='TARGET' scope=spfile;" | sqlplus -s / as sysdba
#echo "shutdown abort" | sqlplus / as sysdba
#echo "startup" | sqlplus -s / as sysdba
#echo "alter system set db_unique_name='TARGET' scope=spfile"| sqlplus -s / as sysdba
end=`date` > $SNAPDIR/end-time
echo
echo
echo "------------------------------------------------------------------------------"
echo
echo "   D A T A B A S E     R E F R E S H    C O M P L E T E                       "
echo "										    "
echo "   Started  :$start                                                           " 
echo "   Ended    :$end                                                             "
echo "------------------------------------------------------------------------------"