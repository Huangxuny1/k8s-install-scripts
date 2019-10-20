#!/bin/bash

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

# current user
user="$(id -un 2>/dev/null || true)"
_cyan "User ${user}"

# indesl dependence
sudo apt install -y \
  apt-transport-https \
  curl ca-certificates \
  > /dev/null

# install docker
install_docker(){
  # add gpg key
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
 
  # install docker use aliyun mirror 
  curl -fsSL https://get.docker.com | bash -s docker –mirror Aliyun
  
  # add user to docker group 
  sudo usermod -aG docker ${user}
  
  # refresh 
  newgrp docker

}

# Check whether docker is installed successfully
command_exists() {
	command -v "$@" > /dev/null 2>&1
}

check_docker(){
  if command_exists docker && [ -e /var/run/docker.sock ]; then
    return 0
  fi 
    return 1
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
kubeadm init --pod-network-cidr=10.244.0.0/16 # --kubernetes-version 1.16.0


# To start using your cluster, you need to run the follong as a regular user:
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

}



apply_network(){

# apply  flannel 
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml

}