#!/bin/bash
##############
# Clone base KVM image for OSE3 install
# Requires base image before install can be started

VIRTDIR=/VirtualMachines
BASE=ose31-base.qcow2
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

function sethost() {
   name="$1"
   ip="$2"
   virt-edit ${VIRTDIR}/${name} /etc/sysconfig/network-scripts/ifcfg-eth0 -e "s/192\.168\.120\.5/${ip}/"
   virt-edit ${VIRTDIR}/${name} /etc/hostname -e "s/.*/${name}.${DOMAIN}/"
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
exit 0 # temporary exit

for n in $(seq 1 $MASTERS)
do
  name=${SYSTEM}master${n}
  rm ${name}.qcow2 ${name}-docker.qcow2 2>/dev/null
  qemu-img create -f qcow2 -b ${BASE} ${name}.qcow2 12G
  qemu-img create -f qcow2 ${name}-docker.qcow2 30G
  chown qemu:qemu ${name}.qcow2 ${name}-docker.qcow2
  # Set correct hostname and IP
  ip=$(getHostIP ${name})
  sethost ${name}.qcow2 ${ip}
  # Create the VM
  createVM ${name}
 done

for n in $(seq 1 $NODES)
do
  name=${SYSTEM}-node${n}
  rm ${name}.qcow2 ${name}-docker.qcow2 2>/dev/null
  qemu-img create -f qcow2 -b ${BASE} ${name}.qcow2 12G
  qemu-img create -f qcow2 ${name}-docker.qcow2 30G
  chown qemu:qemu ${name}.qcow2 ${name}-docker.qcow2
  # Set correct hostname and IP
  ip=$(getHostIP ${name})
  sethost ${name} ${ip} 
  createVM ${name}
done

popd

