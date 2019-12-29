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

# todo
usage() {
  echo -e "Usage: k8s_installer.sh #TODO "
}

# archive
# install docker
install_docker(){
  if [[ $(check_docker) == 0 ]];then
	  _cyan "install docker ... "
    # add gpg key
    #curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
    # install docker use aliyun mirror 
    curl -fsSL https://get.docker.com | bash -s docker --mirror Aliyun 
    # add user to docker group 
    sudo usermod -aG docker ${user}
    # refresh 
    #newgrp docker  
	else
	  _green " "docker" already exist on this system "
     docker_version="$(docker -v | cut -d ' ' -f3 | cut -d ',' -f1)"
	  _cyan ${docker_version}
	fi
}

# archive 
command_exists() {
	command -v "$@" > /dev/null 2>&1
}

# archive 
## check docker whether installed  1 installed  0 no 
check_docker(){
  # Check whether docker is installed successfully
  if command_exists docker && [ -e /var/run/docker.sock ]; then
    echo 1
  else
    echo 0
  fi
}

# archive
# 判断是否关闭swap 如果为关闭则关闭
swap_off(){
  # swapoff permanently (reboot to take effect)
  if [ `grep -c "^#.*swap.*" /etc/fstab` -eq '0' ]; then
    sudo sed -ri 's/.*swap.*/#&/' /etc/fstab
  fi
  # get swap status
  swap_stat=`swapon -s`
  # swapoff immediately
  if [ -z "$swap_stat" ]; then
    echo -e  "${green}swapoff !${none}"
  else
    echo -e "${yellow}swap on ... closing${none} \n$swap_stat"
    sudo swapoff -a
    _green "swapoff ok . " 
  fi
}

# archive
# @param 版本  例如: get_k8s_required_images 1.17.0 默认即为最新版
get_k8s_required_images(){
  # 获取对应版本所需的 镜像
  # 版本格式 v1.17.0或者1.17.0  默认为 stable-1  {参考  https://kubernetes.io/docs/reference/setup-tools/kubeadm/kubeadm-config/#cmd-config-images-list}
  local k8s_images_list=`kubeadm config images list --kubernetes-version ${@:-'stable-1'} 2>/dev/null` # ${@:-${VERSION}}
  echo -e "${magenta}$k8s_images_list ${none}"
  for imageName in ${k8s_images_list[@]} ; do
    echo ${imageName}
    if [[ -z "$(sudo docker images -q ${imageName} 2>/dev/null)" ]]; then
      echo  -e "${magenta} pulling image:\t${imageName} ${none} "
      sudo docker pull registry.cn-hangzhou.aliyuncs.com/google_containers/${imageName/#k8s\.gcr\.io\//}
      sudo docker tag registry.cn-hangzhou.aliyuncs.com/google_containers/${imageName/#k8s\.gcr\.io\//} $imageName > /dev/null
      sudo docker rmi registry.cn-hangzhou.aliyuncs.com/google_containers/${imageName/#k8s\.gcr\.io\//}  > /dev/null
    else
      echo  -e "${magenta} ${imageName} ${none} already  exists ..." 
    fi       
  done
}

# archive
# @param k8s版本 init_k8s_master_node 
init_k8s_master_node(){
  #master node 
  sudo kubeadm init --pod-network-cidr=10.244.0.0/16 --kubernetes-version ${@:-'stable-1'} #1.16.0 # ${@:-${VERSION}}

  # To start using your cluster, you need to run the follong as a regular user:
  if [ ! -d $HOME/.kube ] ;then
    mkdir -p $HOME/.kube
  fi

  if [ ! -f $HOME/.kube/config ] ;then
    sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
    sudo chown $(id -u):$(id -g) $HOME/.kube/config
  fi
}

# archive
# apply network   default: flannel 
# @param url  
apply_network(){
  # 重复执行直至成功 
  repeat kubectl apply -f ${@:-'https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml'}
}


# check(){
#   return `expr $?==0`
# }

check_pods_ready(){
  kubectl get pods   -o $'jsonpath={range .items[*]}{.metadata.name}\t{.status.phase}\n{end}'  ${@:-'--all-namespaces'}
}


# service is active ?   1 active 2 activing 3 inactive 
check_service(){ #Args
  systemctl is-active  $@
}

# do until cmd success
repeat(){
  while true
  do
    $@  && return
  done
}

# archive 
get_ca_hash(){
  openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | openssl rsa -pubin -outform der 2>/dev/null | openssl dgst -sha256 -hex | sed 's/^.* //'
}

# only get default token
get_join_token(){
  kubeadm token list |awk 'NR==2  {print $1}'
}

# archive
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

# archive
install_k8s_ubuntu(){
  #  aliyun mirror k8s gpg  
  curl -fsSL https://mirrors.aliyun.com/kubernetes/apt/doc/apt-key.gpg | sudo apt-key add -  > /dev/null
  # add aliyun mirror k8s source
  sudo tee /etc/apt/sources.list.d/kubernetes.list <<-'EOF'
deb https://mirrors.aliyun.com/kubernetes/apt kubernetes-xenial main
EOF
  #update
  sudo apt update
  # install kubelet kubeadm kubectl
  sudo apt install -y -qq --no-install-recommends kubelet kubeadm kubectl > /dev/null 
}

do_install_ubuntu(){
  install_docker
  swap_off
  #todo  check    
  install_k8s_ubuntu
  get_k8s_required_images
  init_k8s_master_node   # todo Get the join command for the slave node
  apply_network  
}


print_join_info(){
  hash=`get_ca_hash`
  token=`get_join_token`
  echo -e "${cyan}ip:\t$local_ip ${none}"
  echo -e "${green}token:\t$token ${none}"
  echo -e "${green}ca-hash:\t$hash ${none}"
}

do_install_centos(){
  install_docker
  sudo systemctl enable --now docker
  swap_off
  sudo tee /etc/yum.repos.d/kubernetes.repo <<-'EOF'
[kubernetes]
name=Kubernetes
baseurl=http://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=0
repo_gpgcheck=0
gpgkey=http://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg
       http://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg
EOF

  # 关闭SElinux
  sudo setenforce 0
  sudo sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config

  # 安装kubelet kubeadm kubectl
  sudo yum install -y kubelet kubeadm kubectl --disableexcludes=kubernetes

  sudo systemctl enable --now kubelet  # 开机启动kubelet

  # centos7用户还需要设置路由：
  sudo yum install -y bridge-utils.x86_64
  modprobe  br_netfilter  # 加载br_netfilter模块，使用lsmod查看开启的模块
  sudo tee /etc/sysctl.d/k8s.conf <<-'EOF'
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF

  #sysctl --system  # 重新加载所有配置文件
  sudo systemctl disable --now firewalld  # 关闭防火墙

  get_k8s_required_images
  init_k8s_master_node   # todo Get the join command for the slave node
  apply_network
}



do_install(){
  lsb_dist=$( get_distribution )
	lsb_dist="$(echo "$lsb_dist" | tr '[:upper:]' '[:lower:]')"

	case "$lsb_dist" in
		ubuntu)
			if command_exists lsb_release; then
				dist_version="$(lsb_release --codename | cut -f2)"
			fi
			if [ -z "$dist_version" ] && [ -r /etc/lsb-release ]; then
				os_version="$(. /etc/lsb-release && echo "$DISTRIB_CODENAME")"
        echo -e  "OS:\t${cyan} ${os_version}  ${none}"
			fi
      #  dependence
      sudo apt install -y -qq --no-install-recommends \
      apt-transport-https \
      curl ca-certificates \
      > /dev/null #2>&1
      
      # todo params
      do_install_ubuntu
		;;

		debian)
			dist_version="$(sed 's/\/.*//' /etc/debian_version | sed 's/\..*//')"
			case "$dist_version" in
				10)
					dist_version="buster"
				;;
				9)
					dist_version="stretch"
				;;
				8)
					dist_version="jessie"
				;;
			esac
		;;

		centos|fedora)
			if [ -z "$dist_version" ] && [ -r /etc/os-release ]; then
				os_version="$(. /etc/os-release && echo "$PRETTY_NAME")"
        echo -e  "OS:\t${cyan} ${os_version}  ${none}"
			fi

      do_install_centos

		;;

		*)
			if command_exists lsb_release; then
				dist_version="$(lsb_release --release | cut -f2)"
			fi
			if [ -z "$dist_version" ] && [ -r /etc/os-release ]; then
				os_version="$(. /etc/os-release && echo "$PRETTY_NAME")"
        echo -e  "OS:\t${cyan} ${os_version}  ${none}"
			fi
      
		;;

	esac
}


check_sys(){
  #检查是否为Root
  [ $(id -u) != "0" ] && { echo -e ${red} "Error: You must be root to run this script${none}"; exit 1; }
  #检查CPU核数
  [[ `cat /proc/cpuinfo | grep "processor" | wc -l` == 1 ]] && { echo -e ${red} "master node cpu number should be >= 2! ${none}"; exit 1;}


}




### main ###
# current user
user="$(id -un 2>/dev/null || true)"
echo -e  "User:\t${cyan} ${user} ${none}"
local_ip=`ip addr | grep 'state UP' -A2 | tail -n1 | awk '{print $2}' | awk -F"/" '{print $1}'`
echo -e  "IP:\t${cyan} ${local_ip} ${none}"
#check_sys
do_install
print_join_info


