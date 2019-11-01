#!/bin/bash
set -e 
green='\e[92m'
none='\e[0m'

get_ca_hash(){
  openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | openssl rsa -pubin -outform der 2>/dev/null | openssl dgst -sha256 -hex | sed 's/^.* //'
}

# only get default token 
get_join_token(){
  kubeadm token list |awk 'NR==2  {print $1}'
}

echo -e "CA Hash:\t"${green} `get_ca_hash` ${none}
echo -e "Token  :\t"${green} `get_join_token` ${none}
 
