#!/bin/bash
##############
# Clone base KVM image for OSE3 install
# Requires base image before install can be started

set -e

DEBUG=true
RUNDIR=/tmp
VIRTDIR=/VirtualMachines
TEMPLATES=$PWD/templates
BASE=template-ose31.qcow2
MASTERS=1
NODES=3
SYSTEM=none
DNSHOST=192.168.120.1
DOMAIN=rhdemo.net


# parameters

# -s system
# -m masters
# -n nodes

function usage() {
  echo "usage:" >&2
  echo "$0 -s <system> -m <#masters> -n <#nodes>" >&2
  echo "DNS entries from $DNSHOST must be defined for each system-node/master name combination" >&2
  exit 1
}

while getopts :s:m:n: opt; do
  case $opt in 
    s) 
       if [[ $OPTARG = -* ]]; then
         ((OPTIND--))
	 continue
       fi
       SYSTEM=$OPTARG
       ;;
    n) 
       if [[ $OPTARG = -* ]]; then
         ((OPTIND--))
	 continue
       fi
       NUM=$OPTARG
	if [ "$NUM" -eq "$NUM" ] 2>/dev/null
	then
	    NODES=$NUM
	else
	    echo "-n must be nummeric" >&2
	    usage
	    exit 1
        fi
       ;;
    m) 
       if [[ $OPTARG = -* ]]; then
         ((OPTIND--))
	 continue
       fi
       NUM=$OPTARG
	if [ "$NUM" -eq "$NUM" ] 2>/dev/null
	then
	    MASTERS=$NUM
	else
	    echo "-m must be nummeric" >&2
	    usage
	    exit 1
        fi
        ;;
    :) echo "Option -$OPTARG requires an argument" >&2
	exit 1
       ;;
     \?) echo "Invalid option: -$OPTARG" >&2
	exit 1
       ;;
  esac
done

if [[ "$SYSTEM" = "none" ]]
then
   usage
   exit 1
fi

echo System: $SYSTEM
echo Nodes: $NODES
echo Masters: $MASTERS

if [ -f "${VIRTDIR}/${SYSTEM}-master1.qcow2" ]
then
  echo System already exists - refusing to run 1>&2
  exit 1
fi

pushd /VirtualMachines 1>/dev/null

function debugmsg() {
  if [[ "$debug" -eq "true" ]]; then 
    echo $@
  fi
}

function setupGuestfish() {
  file="${1}.qcow2"
  unset $guestfish
  debugmsg "SetupGuestfish $file"
  guestfish[0]="guestfish"
  guestfish[1]="--listen"
  guestfish[2]="-i"
  guestfish[3]="-a"
  guestfish[4]="$file"

  GUESTFISH_PID=
  eval $("${guestfish[@]}")
  if [ -z "$GUESTFISH_PID" ]; then
     echo "error: guestfish didn't start up, see error messages above"
     exit 1
  fi
}

function endGuestfish() {
  if [ ! -z $GUESTFISH_PID ]; then
     debugmsg Closing fish ....
     guestfish --remote -- exit > /dev/null 2>&1
  fi
  unset GUESTFISH_PID
}
trap endGuestfish EXIT ERR

function fishCopy() {
  parms=$@
  guestfish --remote copy-in $parms
}

function createSshDir() {
  debugmsg createSshDir
  guestfish --remote mkdir /root/.ssh
  guestfish --remote chmod 700 /root/.ssh
}

function setupMasterSsh() {
  name="$1"
  debugmsg setupMasterSsh 
  fishCopy $TEMPLATES/id_demo $TEMPLATES/id_demo.pub /root/.ssh
  guestfish --remote chmod 600 /root/.ssh/id_demo
  guestfish --remote chmod 600 /root/.ssh/id_demo.pub
  guestfish --remote chown 0 0 /root/.ssh/id_demo
  guestfish --remote chown 0 0 /root/.ssh/id_demo.pub
}

function setupClientSsh() {
  debugmsg setupClientSsh 
  fishCopy  $HOSTDIR/authorized_keys /root/.ssh
  guestfish --remote chmod 600 /root/.ssh/authorized_keys
}

function createHost() {
  # Creates template files for host
  # Guestfish cannot copy files where the src and dst names are different
  local host="$1"
  debugmsg createHost $HOSTDIR
  mkdir -p $HOSTDIR
  sed -e "s/#IP#/${ip}/" $TEMPLATES/ifcfg-eth0 > $HOSTDIR/ifcfg-eth0
  echo ${host}.${DOMAIN} > $HOSTDIR/hostname
  cp $TEMPLATES/id_demo.pub $HOSTDIR/authorized_keys
}

function sethost() {
   name="$1"
   ip="$2"
   HOSTDIR=$RUNDIR/hosts/$name
   createHost $name
   debugmsg sethost name="$name" ip="$ip"
   fishCopy $HOSTDIR/ifcfg-eth0 /etc/sysconfig/network-scripts
   fishCopy $HOSTDIR/hostname /etc
   fishCopy $TEMPLATES/docker-storage-setup /etc/sysconfig
   createSshDir
   setupClientSsh 
}

function createVM() {
  name="$1"
  virt-install \
    --connect qemu:///system \
    --name ${name} \
    --memory 4096 \
    --network network=ose-network,model=virtio \
    --disk path=${VIRTDIR}/${name}.qcow2,bus=virtio \
    --disk path=${VIRTDIR}/${name}-docker.qcow2,bus=virtio \
    --import \
    --noautoconsole
}

function getHostIP() {
  host="$1"
  ip=$(host ${host}.${DOMAIN}. $DNSHOST | awk 'BEGIN {FS=" ";} /has address/{print $4;}' )
  echo $ip
}

# Ensure we have hostnames for all hosts we're going to create
DNSOK="true"

function checkDNS() {
  name="$1"
  ip=$(getHostIP $name)
  if [[ "$ip" = "" ]]
  then
    DNSOK=false
    echo host $name.$DOMAIN not found on DNS $DNSHOST 1>&2
   else
    echo host $name.$DOMAIN found at $ip
  fi
}

for m in $(seq 1 $MASTERS)
do
  name=${SYSTEM}-master${m}
  checkDNS ${name}
done

for n in $(seq 1 $NODES)
do
  name=${SYSTEM}-node${n}
  checkDNS ${name}
done
  
if [[ $DNSOK != "true" ]]
then
  echo DNS not properly configured - refusing to continue 1>&2
  exit 1
fi

echo All DNS OK

for n in $(seq 1 $MASTERS)
do
  name=${SYSTEM}-master${n}
  debugmsg Setup Master $name ....
  qemu-img create -f qcow2 -b ${BASE} ${name}.qcow2 20G
  qemu-img create -f qcow2 ${name}-docker.qcow2 30G
  chown qemu:qemu ${name}.qcow2 ${name}-docker.qcow2
  # Set correct hostname and IP
  ip=$(getHostIP ${name})
  setupGuestfish ${name} 
  sethost ${name} ${ip}
  setupMasterSsh ${name} 
  # Master is always a client too
  endGuestfish
  # Create the VM
  createVM ${name}
 done

for n in $(seq 1 $NODES)
do
  name=${SYSTEM}-node${n}
  debugmsg Setup Node $name
  qemu-img create -f qcow2 -b ${BASE} ${name}.qcow2 20G
  qemu-img create -f qcow2 ${name}-docker.qcow2 30G
  chown qemu:qemu ${name}.qcow2 ${name}-docker.qcow2
  # Set correct hostname and IP
  ip=$(getHostIP ${name})
  setupGuestfish ${name} 
  sethost ${name} ${ip} 
  setupClientSsh ${name}
  endGuestfish
  createVM ${name}
done

set +x

popd

