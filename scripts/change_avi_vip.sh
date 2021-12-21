#!/bin/bash
#
# Script for VIP Frontend Network Selection
#   useful for vsphere with Tanzu and AVI scenarios
#   in which you want to set the usable network that
#   AVI IPAM use to realize the virtual networks
# Tested in version 21.1.2

clear
figlet AVI VIP Network Changer
echo
echo

COOKIEFILE="avi.cookie"
GETFILE="avi.get"
POSTFILE="avi.post"
PUTFILE="avi.put"
LOGOUTFILE="AVI_LOGOUT"
DEFAULT_IP="172.25.5.5"
DEFAULT_ADMIN="admin"
DEFAULT_PASS="password"
DEFVERSION="21.1.2"

# See if device IP has been given as first argument
validIP=0
while [ $validIP == 0 ]
do
    echo -n "Please provide the IP address of the AVI controller to login: [$DEFAULT_IP] "
    read IP
    if [ -z "$IP" ]
    then
      IP=$DEFAULT_IP
      echo "$DEFAULT_IP will be used"
      validIP=1
    else
    if [[ $IP  =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]
    then
        validIP=1
    else
        echo "Given IP is not a valid IPv4 address"
        echo
    fi
    fi
done

user=0
while [ $user == 0 ]
do
    echo -n "Please provide an administrator username: [$DEFAULT_ADMIN]"
    read USER
    # See if some input was given
    if [ -z "$USER" ]
    then
        USER=$DEFAULT_ADMIN
        echo "$DEFAULT_ADMIN will be used as username"
        user=1
    else
        user=1
        echo "$USER will be used as username"
    fi
done

pass=0
while [ $pass == 0 ]
do
    echo -n "Please provide the password for this user: "
    read -s PASS
    # See if some input was given
    if [ -z "$PASS" ]
    then
        echo "No password was given... default password will be used"
        PASS=$DEFAULT_PASS
        pass=1
    else
        pass=1
        echo
    fi
done

echo -n "Please provide the API version to use [$DEFVERSION]: "
read VERSION
# See if some input was given
if [ -z "$VERSION" ]
then
    VERSION=$DEFVERSION
    echo "No specific version specified, using $VERSION"
    echo
else
    echo "Will use version: $VERSION"
fi
sleep 1

AUTH="{\"username\":\"$USER\",\"password\":\"$PASS\"}"

echo -n "Log in as $USER..."
curl -k -s --connect-timeout 5 -c $COOKIEFILE -X POST -H 'Content-Type: application/json' -d $AUTH https://$IP/
login >/dev/null
RESULT=$?
if [ "$RESULT" -eq 0 ]
then
    echo -n "..."
else
    /bin/rm -f $COOKIEFILE
    echo "failed with exit code $RESULT"
    exit 1
fi

# Do we have a cookie file? (authentication was ok?)
if [ ! -f "$COOKIEFILE" ]
then
    echo "Login failed, no cookie file created."
    exit 1
else
    # Getting CSRF token from cookie file
    CSRFTOKEN=$(grep csrftoken $COOKIEFILE | awk '{ print $7 }')
    # Do we have a token?
    if [ -z "$CSRFTOKEN" ]
    then
        echo "Login failed, no CSRFTOKEN set. Check your credentials!"
        /bin/rm -f $COOKIEFILE
        exit 1
    else
        echo "ok"
    fi
fi

# Saving curl in local dir for GET, POST and PUT operations commands
echo "-b $COOKIEFILE" > $GETFILE
echo "-H \"X-CSRFToken:$CSRFTOKEN\"" >> $GETFILE
echo "-H \"X-Avi-Version:$VERSION\"" >> $GETFILE
echo "-H \"Accept-Encoding:application/json\"" >> $GETFILE
echo "-X GET" >>  $GETFILE

echo "-b $COOKIEFILE" > $POSTFILE
echo "-H \"X-CSRFToken:$CSRFTOKEN\"" >> $POSTFILE
echo "-H \"X-Avi-Version:$VERSION\"" >> $POSTFILE
echo "-H \"Content-Type:application/json\"" >> $POSTFILE
echo "-H \"Referer:https://$IP\"" >> $POSTFILE
echo "-X POST" >> $POSTFILE

echo "-b $COOKIEFILE" > $PUTFILE
echo "-H \"X-CSRFToken:$CSRFTOKEN\"" >> $PUTFILE
echo "-H \"X-Avi-Version:$VERSION\"" >> $PUTFILE
echo "-H \"Content-Type:application/json\"" >> $PUTFILE
echo "-H \"Referer:https://$IP\"" >> $PUTFILE
echo "-X PUT" >> $PUTFILE

#----- Creating logout script  -----

echo "curl -k -b $COOKIEFILE -X POST -H \"X-CSRFToken:$CSRFTOKEN\" -H \"Referer:https://$IP\" \"https://$IP/log
out\"" > $LOGOUTFILE
echo "rm $COOKIEFILE $GETFILE $POSTFILE $PUTFILE $LOGOUTFILE" >> $LOGOUTFILE
chmod u+x $LOGOUTFILE

#---------------


echo "----------"
echo "Ready to retrieve data from AVI controller at $IP using version $VERSION:"
echo
echo
echo "When finished, Logout to the AVI controller via ./$LOGOUTFILE"
echo
read -p "Press enter to continue...."

# COLORS FOR ECHO PRINTING
YELLOW='\033[1;33m'
RED='\033[1;31m'
GREEN='\033[1;32m'
NC='\033[0m'

clear
echo -e "   ${RED}Retrieving data from controller...${NC}"
echo
echo -e "${YELLOW}------------------------------------------------------------${NC}"
echo -e "   ${YELLOW}STEP 1.- Getting list of cloud providers${NC}"
echo -e "${YELLOW}------------------------------------------------------------${NC}"
echo

curl -s -k -K avi.get "https://172.25.5.5/api/cloud" | jq -c '.results[]| .name as $name | .url as $cloud_ref |
 .ipam_provider_ref as $ipam_provider_ref | {name: $name, cloud_ref: $cloud_ref, ipam_provider_ref: $ipam_provi
der_ref}' > cloud_output.json


# ---- PRESENT OPTIONS FOR AVI CLOUDS ----
readarray -t CLOUDS < <(cat cloud_output.json | jq --slurp '.[].name' | sed -e 's/^"//' -e 's/"$//')
echo
echo -e "   ${YELLOW}From the list below, select the cloud provider you want to configure:${NC}"
select choice in "${CLOUDS[@]}"; do
  [[ -n $choice ]] || { echo "Invalid choice. Please try again." >&2; continue; }
  break # valid choice was made; exit prompt.
done

read -r CLOUD_NAME <<<"$choice"

echo
echo -e "Your cloud provider selection is: ${GREEN}${CLOUD_NAME}${NC}"
echo
echo

# ------ Retrieve current IPAM and network settings for specified cloud

echo -e "${YELLOW}------------------------------------------------------------${NC}"
echo -e "   ${YELLOW}STEP 2.- Displaying current settings for cloud ${GREEN}$CLOUD_NAME${NC}"
echo -e "${YELLOW}------------------------------------------------------------${NC}"

# Get IPAMProfile configured usable networks
IPAM=$(cat cloud_output.json | jq --slurp --arg CLOUD_NAME "$CLOUD_NAME" '.[] | select(.name == $CLOUD_NAME) |
.ipam_provider_ref' | sed -e 's/^"//' -e 's/"$//')
curl -s -k -K avi.get "https://172.25.5.5/api/ipamdnsproviderprofile" | jq -c --arg URL "$IPAM" '.results[] | .
name as $name | .internal_profile.usable_networks[].nw_ref as $usable_net | .uuid as $uuid | select (.url == $U
RL) | {name: $name, uuid: $uuid, usable_net: $usable_net}' > ipam_output.json


# Get current network details
IPAM_PROVIDER_NAME=$(cat ipam_output.json | jq '.name' | sed -e 's/^"//' -e 's/"$//')
USABLE_NET=$(cat ipam_output.json | jq '.usable_net' | sed -e 's/^"//' -e 's/"$//')
curl -s -k -K avi.get "https://172.25.5.5/api/network" | jq -r --arg URL "$USABLE_NET" '.results[] | .name as $
name | .configured_subnets as $configured_subnets | select (.url == $URL) | {name: $name, configured_subnets: $
configured_subnets}' > network_output.json

echo
echo -e "   ${YELLOW}Network_Name:${NC} $(cat network_output.json | jq -s '.[]  | (.name)' | sed -e 's/^"//' -e
 's/"$//')"
echo -e "   ${YELLOW}Configured Subnets:${NC} $(cat network_output.json | jq -s '.[]  | .configured_subnets[].p
refix.ip_addr.addr' | sed -e 's/^"//' -e 's/"$//')"
echo -e "   ${YELLOW}Mask Lenght:${NC} $(cat network_output.json | jq -s '.[]  | .configured_subnets[].prefix.m
ask' | sed -e 's/^"//' -e 's/"$//')"
echo
echo -e "        ${YELLOW}and it has the following ranges configured${NC}"
echo
cat network_output.json | jq -c '.configured_subnets[].static_ip_ranges[] | {first_IP: .range.begin.addr, last_
IP: .range.end.addr, type: .type}'

echo
# ------ Ask for change confirmation
while true; do
    read -p "Do you wish to change current settings? (y/n)" yn
    case $yn in
        [Yy]* ) break;;
        [Nn]* ) echo "Now exiting"; exit;;
        * ) echo "Please answer yes or no.";;
    esac
done

CLOUD_REF=$(cat cloud_output.json | jq --slurp --arg CLOUD_NAME "$CLOUD_NAME" '.[] | select(.name == $CLOUD_NAM
E) | .cloud_ref' | sed -e 's/^"//' -e 's/"$//')
curl -s -k -K avi.get "https://172.25.5.5/api/network" | jq -r --arg CLOUD_REF "$CLOUD_REF" '.results[] | selec
t( .configured_subnets != null and .cloud_ref == $CLOUD_REF)' > configured_networks.json


cat configured_networks.json | jq -s  '.[] | .name as $name | .url as $url | .configured_subnets[].prefix.ip_ad
dr.addr as $network | .configured_subnets[].prefix.mask|tostring as $mask | {name: $name, nw_ref: $url, network
: $network, mask: $mask}' > networks_subnets.json

# Create friendly key name for option menu
cat networks_subnets.json | jq '. | . + {"friendly_name": (.name+" with network "+.network+"/"+.mask)}' > netwo
rks_friendly.json

# ----------- Present options

readarray -t NETWORKS < <(cat networks_friendly.json | jq --slurp .[].friendly_name | sed -e 's/^"//' -e 's/"$/
/')
#clear
echo
echo
echo -e "${YELLOW}------------------------------------------------------------${NC}"
echo -e "   ${YELLOW}STEP 3.- From the list below, select the network you want to use to deploy your VIP servic
es${NC}"
echo -e "${YELLOW}------------------------------------------------------------${NC}"

select choice in "${NETWORKS[@]}"; do
  [[ -n $choice ]] || { echo "Invalid choice. Please try again." >&2; continue; }
  break # valid choice was made; exit prompt.
done

# Split the chosen line into ID and serial number.
read -r NETWORK_FRIENDLY <<<"$choice"

echo "Your new network for VIP services is network: $NETWORK_FRIENDLY"

# GET The IPAM UUID
IPAM_UUID=$(cat ipam_output.json | jq '.uuid' | sed -e 's/^"//' -e 's/"$//')
NW_REF=$(cat networks_friendly.json | jq --arg NETWORK_FRIENDLY "$NETWORK_FRIENDLY" '. | select(.friendly_name
== $NETWORK_FRIENDLY) | .nw_ref' | sed -e 's/^"//' -e 's/"$//')

# Create template JSON inserting nw_ref with previous network selection
curl -s -k -K avi.get "https://172.25.5.5/api/ipamdnsproviderprofile/${IPAM_UUID}" | jq --arg NW_REF "$NW_REF"
'.internal_profile.usable_networks[] ={"nw_ref": $NW_REF}' > put_body.json

# Apply new changes
echo "  Reprogramming AVI Controller with new settings..."
echo
curl -s -k -K avi.put -d @put_body.json "https://172.25.5.5/api/ipamdnsproviderprofile/${IPAM_UUID}" > final.js
on
echo " Done"
# -------Display new settings
echo
echo
echo -e "${YELLOW}------------------------------------------------------------${NC}"
echo -e "  ${RED}SUMMARY: The new settings configured are displayed below${NC}"
echo -e "${YELLOW}------------------------------------------------------------${NC}"
# -------- Get New Configured Usable network detail
curl -s -k -K avi.get "https://172.25.5.5/api/ipamdnsproviderprofile" | jq -c --arg URL "$IPAM" '.results[] | .
name as $name | .internal_profile.usable_networks[].nw_ref as $usable_net | .uuid as $uuid | select (.url == $U
RL) | {name: $name, uuid: $uuid, usable_net: $usable_net}' > ipam_output.json

IPAM_PROVIDER_NAME=$(cat ipam_output.json | jq '.name' | sed -e 's/^"//' -e 's/"$//')
USABLE_NET=$(cat ipam_output.json | jq '.usable_net' | sed -e 's/^"//' -e 's/"$//')
curl -s -k -K avi.get "https://172.25.5.5/api/network" | jq -r --arg URL "$USABLE_NET" '.results[] | .name as $
name | .configured_subnets as $configured_subnets | select (.url == $URL) | {name: $name, configured_subnets: $
configured_subnets}' > network_output.json

echo
echo -e "   ${YELLOW}Network_Name:${NC} $(cat network_output.json | jq -s '.[]  | (.name)' | sed -e 's/^"//' -e
 's/"$//')"
echo -e "   ${YELLOW}Configured Subnets:${NC} $(cat network_output.json | jq -s '.[]  | .configured_subnets[].p
refix.ip_addr.addr' | sed -e 's/^"//' -e 's/"$//')"
echo -e "   ${YELLOW}Mask Lenght:${NC} $(cat network_output.json | jq -s '.[]  | .configured_subnets[].prefix.m
ask' | sed -e 's/^"//' -e 's/"$//')"
echo
echo -e "        ${YELLOW}new Virtual Services will use following ranges: ${NC}"
echo


cat network_output.json | jq -c '.configured_subnets[].static_ip_ranges[] | {first_IP: .range.begin.addr, last_
IP: .range.end.addr, type: .type}'
rm ipam_output.json networks_friendly.json network_output.json networks_subnets.json configured_networks.json c
loud_output.json put_body.json
echo
echo
echo "Cleaning temporary files ..."
./AVI_LOGOUT
echo "Logout from AVI Controller done"
