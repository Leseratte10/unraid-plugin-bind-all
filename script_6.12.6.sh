# Library file: /etc/rc.d/rc.library.source
# Used by nfsd, ntpd, rpc, samba, nginx, sshd, avahidaemon, show_interfaces
#
# bergware - updated for Unraid, June 2023
# Leseratte10 - updated to remove new IP code and make IPv6 work again, January 2024

WIREGUARD="/etc/wireguard"
NETWORK_INI="/var/local/emhttp/network.ini"
NETWORK_EXTRA="/boot/config/network-extra.cfg"


IPv() {
  t=${1//[^:]}
  [[ ${#t} -le 1 ]] && echo 4 || echo 6
}

this() {
  case $CALLER in
  'avahi')
    grep -Pom1 "^$1=\K.*" $CONF
    ;;
  'smb')
    grep -Pom1 "^$1 = \K.*" $CONF
    ;;
  'ntp'|'ssh')
    grep -Po "^$1 \K\S+" $CONF|tr '\n' ' '|sed 's/ $//'
    ;;
  'nfs')
    grep -Pom1 "^RPC_NFSD_OPTS=\"$OPTIONS \K[^\"]+" $NFS
    ;;
  'rpc')
    grep -Pom1 "^RPCBIND_OPTS=\"\K[^\"]+" $RPC
    ;;
  'nginx')
    now=();
    for addr in $(awk '$1=="listen" && $2~/^[0-9]|\[/ && $0~/http2; #.*$/{print $2}' $SERVERS 2>/dev/null); do
      # extract ipv4 / ipv6 address
      [[ $(IPv $addr) == 4 ]] && addr=${addr%:*} || addr=${addr#*[} addr=${addr%]*}
      now+=($addr)
    done
    # return addresses
    echo ${now[@]}
    ;;
  esac
}

scan() {
  grep -Pom1 "^$1=\"?\K[^\"]+" $2
}

max6() {
  # ipv6 addresses in long notation
  f=:ffff:
  for x in $*; do
    read a m < <(IFS=/; echo $x)
    [[ $a =~ $f && $a =~ '.' ]] && b=${a#*$f} a=${a%$f*}$f:0 || b=
    c=${a//[^:]/}
    [[ ${a:0:1} == : ]] && a=0${a}
    [[ ${a:${#a}-1} == : ]] && a=${a}0
    a=${a/::/:$(for((i=1;i<=$((8-${#c}));i++)); do printf "0:"; done)}
    d= a=$(for q in ${a//:/ }; do printf "$d%04x" "0x$q"; d=:; done)
    [[ -n $b ]] && d= a=${a%$f*}${f}$(for q in ${b//./ }; do printf "$d%03x" "0x$q"; d=.; done)
    [[ -z $m ]] && echo $a || echo $a/$m
  done
}

min6() {
  # ipv6 address in short notation
  f=:ffff:
  [[ -n $1 ]] && read a m < <(IFS=/; echo $1) || return
  [[ $a =~ $f && $a =~ '.' ]] && b=${a#*$f} a=${a%$f*}$f || b=
  d= a=:$(for q in ${a//:/ }; do printf "$d%x" "0x$q"; d=:; done)
  a=${a/$(grep -Po ':(0(:|$)){2,8}' <<< $a|sort|tail -1)/::}
  [[ ${a:0:2} != :: ]] && a=${a:1}
  [[ -n $b ]] && d= a=${a%$f*}:$(for q in ${b//./ }; do printf "$d%x" "0x$q"; d=.; done)
  [[ -z $m ]] && echo $a || echo $a/$m
}

wipe() {
  wet=($*)
  # remove temporary (privacy extensions) and host ipv6 addresses
  for tmp in $(ip -br -6 addr show scope global temporary dev $wet 2>/dev/null|sed -r 's/metric [0-9]+//'|awk '{$1=$2="";print}'); do
    for i in ${!wet[@]}; do
      [[ ${wet[$i]} == $tmp || (${wet[$i]} =~ '::' && ${wet[$i]#*/} == 128) ]] && unset 'wet[i]'
    done
  done
  # return cleaned-up list without interface name
  echo ${wet[@]/$wet}
}

main2() {
  min6 $(max6 $(wipe $*)|sort|head -1)
}

show() {
  case $# in
    1) ip -br addr show scope global to $1 2>/dev/null|awk '{print $1;exit}';;
    2) ip -br addr show scope global $1 $2 2>/dev/null|awk '{print $3;exit}';;
    3) if [[ $1 == -6 ]]; then main2 $(ip -br -6 addr show scope global $2 $3 2>/dev/null|sed -r 's/metric [0-9]+//'|awk '{$2="";print;exit}'); else ip -br -4 addr show scope global $2 $3 2>/dev/null|awk '{print $3;exit}'; fi;;
  esac
}

sub() {
  [[ -z $1 ]] && return
  if [[ $CALLER == smb && -z $deny6 ]]; then
    # replace netmask
    [[ $(IPv $1) == 4 ]] && echo ${1/\/32/\/24} || echo ${1/\/128/\/64}
  else
    # remove netmask
    echo ${1/\/*}
  fi
}

remove() {
  [[ -z $1 ]] && return
  for i in ${!bind[@]}; do
    [[ ${bind[$i]} == $1 ]] && unset 'bind[i]'
  done
}

isname() {
  [[ -z ${1//[^.:]} || ${1//[^.:]} == . ]] && return 0 || return 1
}

extra_name() {
  return
}

extra_addr() {
  return
}

check() {

  ipv4=yes
  ipv6=yes
  family=any
  bind+=("::")
  bind+=("0.0.0.0")

  # add loopback interface
  if [[ "smb nfs" =~ $CALLER ]]; then
    [[ $ipv4 == yes ]] && bind+=(127.0.0.1)
    [[ $ipv6 == yes ]] && bind+=(::1)
  fi


  if [[ $CALLER == ssh ]]; then
    # bind stays array
    bind=(${bind[@]})
  else
    # convert array to string
    bind=${bind[@]}
    [[ $CALLER == avahi ]] && bind=${bind// /,}
  fi
  return 0
}
