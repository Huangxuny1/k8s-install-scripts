
```
usage: 

$ chmod u+x k8s_installer.sh
$ ./k8s_installer.sh
```


**kubernetes 自动安装脚本**

- [x] 安装Docker (Aliyun镜像)
- [x] 安装kubeadm kubelet kubectl
- [x] 关闭swap
- [x] 根据 `kubeadm config images list`从阿里云下载对应的镜像并打tag
- [x] master init
- [x] apply network

**TODO**

- [ ] 支持更多发行版
- [ ] 更多的check
- [ ] 根据配置 ssh 从节点自动加入(token ca-hash)
- [ ] service状态判断(function check_service )
- [ ] pods status  ( function check_pods_ready )
- [ ] 更多网络方案  (Calico 等等)
- [ ] 使用说明 (usage)

<h2> 欢迎提 issue 和 PR 一起完善 </h2>

```
 kubectl get pods   -o $'jsonpath={range .items[*]}{.metadata.name}\t{.status.containerStatuses[0].state}\n{end}'  ${@:-'--all-namespaces'}
 docker pull registry.cn-hangzhou.aliyuncs.com/google_containers/kubernetes-dashboard-amd64:v1.10.1
 function __is_pod_ready() {
  [[ "$(kubectl get po "$1" -o 'jsonpath={.status.conditions[?(@.type=="Ready")].status}')" == 'True' ]]
}
kubeadm token create --print-join-command  # 创建新的token并打印node加入命令

quay-mirror.qiniu.com/coreos/   # flannel 镜像
```
