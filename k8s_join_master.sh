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

# install docker u
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

# Check whether docker is installed successfully
command_exists() {
	command -v "$@" > /dev/null 2>&1
}

## check docker whether installed   1 installed  0 no 
check_docker(){
  if command_exists docker && [ -e /var/run/docker.sock ]; then
    echo 1
  fi 
    echo 0
}

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



get_k8s_required_images(){
# get images 
k8s_images_list=`kubeadm config images list 2>/dev/null`

echo -e  " ${magenta}$k8s_images_list ${none}"

for imageName in ${k8s_images_list[@]} ; do
        echo ${imageName/#k8s\.gcr\.io\//}
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
sudo apt install -y -qq --no-install-recommends kubelet kubeadm kubectl
}




do_join_master(){
    echo $master_ip
    echo $token
    echo $hash

    install_docker
    install_k8s_ubuntu
    get_k8s_required_images
    # join 
    sudo kubeadm join ${master_ip}:6443 --token ${token} \
    --discovery-token-ca-cert-hash sha256:${ca_hash}
}


master_ip=$1
token=$2
ca_hash=$3
do_join_master
