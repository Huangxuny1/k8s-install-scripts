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


# current user
user="$(id -un 2>/dev/null || true)"


sudo apt install -y apt-transport-https
# install docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

# 关闭 swap
sed -ri 's/.*swap.*/#&/' /etc/fstab


#  aliyun mirror k8s gpg  
sudo curl -s https://mirrors.aliyun.com/kubernetes/apt/doc/apt-key.gpg | sudo apt-key add -

sudo tee /etc/apt/sources.list.d/kubernetes.list <<-'EOF'
deb https://mirrors.aliyun.com/kubernetes/apt kubernetes-xenial main
EOF

sudo apt update


# install kubelet kubeadm kubectl
sudo apt install -y kubelet kubeadm kubectl

# get images 
k8s_images_list=`kubeadm config images list 2>/dev/null`

echo $k8s_images_list

for imageName in ${k8s_images_list[@]} ; do
        echo ${imageName/#k8s\.gcr\.io\//}
        docker pull registry.cn-hangzhou.aliyuncs.com/google_containers/${imageName/#k8s\.gcr\.io\//}
        docker tag registry.cn-hangzhou.aliyuncs.com/google_containers/${imageName/#k8s\.gcr\.io\//} $imageName
        docker rmi registry.cn-hangzhou.aliyuncs.com/google_containers/${imageName/#k8s\.gcr\.io\//}
done

# swapoff
swap_stat=`swapon -s`
echo "---"
if [ -z "$swap_stat" ]; then
    _green "${green} swapoff ! ${none}"
else
    echo -e "${yellow}  swap on ...  ${none} \n  $swap_stat  \n"
    sudo swapoff -a
    _green "swapoff ok . " 
fi


#master node 
kubeadm init --pod-network-cidr=10.244.0.0/16 # --kubernetes-version 1.16.0


# To start using your cluster, you need to run the follong as a regular user:
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config


# apply  flannel 
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
