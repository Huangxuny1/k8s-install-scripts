#!/bin/bash

set -e 

# terminal color 
red='\e[91m'
green='\e[92m'
yellow='\e[93m'
magenta='\e[95m'
cyan='\e[96m'
none='\e[0m'

_red() { echo -e ${red}$*${none}; }
_green() { echo -e ${green}$*${none}; }
_yellow() { echo -e ${yellow}$*${none}; }
_magenta() { echo -e ${magenta}$*${none}; }
_cyan() { echo -e ${cyan}$*${none}; }



usage() {
  #todo
  echo -e "Usage: k8s.sh [OPTIONS]
	master: install docker, kubectl, kubelet, kubeadm and creates the cluster
	worker: also installs docker, kubectl, kubelet and kubeadm but executes the join
		with the master. Takes three arguments: 'master_ip', 'token' and a 'hash'."
}


# install docker u
install_docker(){
  # add gpg key
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
 
  # install docker use aliyun mirror 
  curl -fsSL https://get.docker.com | bash -s docker --mirror Aliyun
  
  # add user to docker group 
  sudo usermod -aG docker ${user}
  
  # refresh 
  newgrp docker

}

# Check whether docker is installed successfully
command_exists() {
	command -v "$@" > /dev/null 2>&1
}

# u
check_docker(){
  if command_exists docker && [ -e /var/run/docker.sock ]; then
    echo 1
  fi 
    echo 0
}



swap_off(){
# swapoff permanently (reboot to take effect)
sed -ri 's/.*swap.*/#&/' /etc/fstab

# swapoff immediately
swap_stat=`swapon -s`

if [ -z "$swap_stat" ]; then
    _green "${green} swapoff ! ${none}"
else
    echo -e "${yellow}  swap on ...  ${none} \n  $swap_stat  \n"
    sudo swapoff -a
    _green "swapoff ok . " 
fi
}

install_k8s(){
#  aliyun mirror k8s gpg  
curl -fsSL https://mirrors.aliyun.com/kubernetes/apt/doc/apt-key.gpg | sudo apt-key add -

# add aliyun mirror k8s source
sudo tee /etc/apt/sources.list.d/kubernetes.list <<-'EOF'
deb https://mirrors.aliyun.com/kubernetes/apt kubernetes-xenial main
EOF

#update
sudo apt update

# install kubelet kubeadm kubectl
sudo apt install -y kubelet kubeadm kubectl

}

get_k8s_required_images(){
# get images 
k8s_images_list=`kubeadm config images list 2>/dev/null`

echo $k8s_images_list

for imageName in ${k8s_images_list[@]} ; do
        echo ${imageName/#k8s\.gcr\.io\//}
        docker pull registry.cn-hangzhou.aliyuncs.com/google_containers/${imageName/#k8s\.gcr\.io\//}
        docker tag registry.cn-hangzhou.aliyuncs.com/google_containers/${imageName/#k8s\.gcr\.io\//} $imageName
        docker rmi registry.cn-hangzhou.aliyuncs.com/google_containers/${imageName/#k8s\.gcr\.io\//}
done

}


init_k8s_master_node(){
#master node 
sudo kubeadm init --pod-network-cidr=10.244.0.0/16 # --kubernetes-version 1.16.0


# To start using your cluster, you need to run the follong as a regular user:
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

}



apply_network(){
# apply  flannel 
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
}


check(){
  return `expr $?==0`
}

get_distribution() {
	lsb_dist=""
	# Every system that we officially support has /etc/os-release
	if [ -r /etc/os-release ]; then
		lsb_dist="$(. /etc/os-release && echo "$ID")"
	fi
	# Returning an empty string here should be alright since the
	# case statements don't act unless you provide an actual value
	echo "$lsb_dist"
}


# perform some very rudimentary platform detection
#	lsb_dist=$( get_distribution )
#	lsb_dist="$(echo "$lsb_dist" | tr '[:upper:]' '[:lower:]')"
#
#	case "$lsb_dist" in
#
#		ubuntu)
#			if command_exists lsb_release; then
#				dist_version="$(lsb_release --codename | cut -f2)"
#			fi
#			if [ -z "$dist_version" ] && [ -r /etc/lsb-release ]; then
#				dist_version="$(. /etc/lsb-release && echo "$DISTRIB_CODENAME")"
#			fi
#		;;
#
#		debian)
#			dist_version="$(sed 's/\/.*//' /etc/debian_version | sed 's/\..*//')"
#			case "$dist_version" in
#				10)
#					dist_version="buster"
#				;;
#				9)
#					dist_version="stretch"
#				;;
#				8)
#					dist_version="jessie"
#				;;
#			esac
#		;;
#
#		centos)
#			if [ -z "$dist_version" ] && [ -r /etc/os-release ]; then
#				dist_version="$(. /etc/os-release && echo "$VERSION_ID")"
#			fi
#		;;
#
#		*)
#			if command_exists lsb_release; then
#				dist_version="$(lsb_release --release | cut -f2)"
#			fi
#			if [ -z "$dist_version" ] && [ -r /etc/os-release ]; then
#				dist_version="$(. /etc/os-release && echo "$VERSION_ID")"
#			fi
#		;;
#
#	esac



do_install(){
	if [[ $(check_docker) == 0 ]];then
		_cyan "install docker ... "
		install_docker
	else
		_green " "docker" already exist on this system "
	fi
  
}


# current user
user="$(id -un 2>/dev/null || true)"
_cyan "User ${user}"
local_ip=`ip addr | grep 'state UP' -A2 | tail -n1 | awk '{print $2}' | awk -F"/" '{print $1}'`
_cyan "Local IP6 is ${local_ip}"

#  dependence
sudo apt install -y \
  apt-transport-https \
  curl ca-certificates \
  > /dev/null 2>&1

do_install
#kubectl get pods   -o $'jsonpath={range .items[*]}{.metadata.name}\t{.status.phase}\n{end}'  --all-namespaces