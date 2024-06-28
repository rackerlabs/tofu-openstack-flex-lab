#!/usr/bin/env bash
ansible   -m shell -a 'hostnamectl set-hostname {{ inventory_hostname }}' --become all
ansible - -m shell -a "grep 127.0.0.1 /etc/hosts | grep -q {{ inventory_hostname }} || sed -i 's/^127.0.0.1.*/127.0.0.1 {{ inventory_hostname }} localhost.localdomain localhost/' /etc/hosts" --become all
cd /opt/genestack/ansible/playbooks && ansible-playbook host-setup.yml
cd /opt/genestack/submodules/kubespray && ansible-playbook cluster.yml -b
get_kube_config.sh