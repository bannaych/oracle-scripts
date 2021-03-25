#!/bin/bash
tput clear
BOLD=`tput smso`
NORM=`tput rmso`
REV=`tput rev`
RED=`tput setaf 2`
RESET=`tput sgr0`
JsonContent="Content-Type: application/json"
XmlContent="Content-Type: application/xml"
ApiToken=aa009fd2-7686-7d48-8698-26b7eb2ae841
ApiToken1=4ac5c338-a688-3c77-d6cb-dcfd3a5b2424
Cookie=/tmp/cookie.jar

MaxTimeout=30
Array1=10.226.224.112
Array2=10.226.116.122
Curl=/usr/bin/curl
HOST1=ora-source
HOST2=ora-target


auth ()
{

${Curl} -s -k -m ${MaxTimeout} -H "${JsonContent}" -c ${Cookie} -X POST https://${Array1}/api/1.17/auth/session -d "
{
        \"api_token\": \"${ApiToken}\"
}
"  >/dev/null
}


auth1 ()
{

${Curl} -s -k -m ${MaxTimeout} -H "${JsonContent}" -c ${Cookie} -X POST https://${Array1}/api/1.17/auth/session -d "
{
        \"api_token\": \"${ApiToken1}\"
}
"  >/dev/null
}

stats ()
{
${Curl} -s -k -m 20 -H "Content-Type: application/json" -b ${Cookie} -X GET https://${Array1}/api/1.19/pod/ora-target|awk -F, '{print $11}'
}

rep ()
{
${Curl} -s -k -m 20 -H "Content-Type: application/json" -b ${Cookie} -X GET https://${Array1}/api/1.19/pod/replica-link|awk -F, '{print $1}'
}

lag ()
{
${Curl} -s -k -m 20 -H "Content-Type: application/json" -b ${Cookie} -X GET https://${Array1}/api/1.19/pod/replica-link|awk -F, '{print $3}'
}
auth
#auth1
STATUS="$(stats|awk -F: '{print $2}')"
REP="$(rep|awk -F: '{print $2}')"
LAG="$(lag|awk -F: '{print $2}')"
echo " "
echo " "
echo " "
echo " "
echo "                                 $BOLD Oracle  ActiveDR Configuration $NORM"
echo " "
echo " "
echo "  +-----------------------------------------+        +------------------------------------------+"
echo "  |                                         |        |                                          |"
echo "  |              PRODUCTION                 |        |          DISASTER RECOVERY               |"
echo "  |                                         |        |                                          |"
echo "  |    RedDot       :  10.226.116.122       |        |    RedDotX    :      10.226.224.112      |"
echo "  |    Prod Node IP :  10.226.225.146       |        |    DR Node IP :      10.226.225.147      |"
echo "  |    Hostname     :  ora-source           | <----> |    Hostname   :      ora-target          |"
echo "  |    Oracle Ver   :  19c                  |        |    Oracle Ver :      19c                 |"
echo "  |    Source POD   :  ora-source           | <----> |    Target POD :      ora-target          |"
echo "  |    POD Status   :  promoted             |        |    POD STATUS :      ${STATUS:2:-1}             |"
echo "  |    Rep Status   :  ${REP:2:-1}          |        |    Rep STATUS :      ${REP:2:-1}         |"
echo "  |    Lag in ms    : ${LAG}                 |        |    Lag in ms  :     ${LAG}                |"
echo "  |                                         |        |                                          |"
echo "  |                                         |        |                                          |"
echo "  +-----------------------------------------+        +------------------------------------------+"
echo " "
echo "  Press Enter to exit..."
tput cup 24 25
read ans
