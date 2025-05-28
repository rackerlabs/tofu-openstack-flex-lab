#!/usr/bin/env python
"""dynamic inventory for lab environment to be used with ansible"""

import argparse
import json
from typing import Type
from os import getenv
import sys
import openstack
from ansible.plugins.inventory import BaseInventoryPlugin
from ansible.inventory.data import InventoryData
from ansible.inventory.host import Host
from ruamel.yaml import YAML


class InventoryModule(BaseInventoryPlugin):
    """WIP Custom inventory builder"""
    NAME = 'lab_inventory'

    def __init__(self, cloud):
        super(InventoryModule, self).__init__()
        self._hosts = set()
        self.os_client = openstack.connect(cloud)

    def parse(self, inventory, loader, path, cache=True):
        super(InventoryModule, self).parse(inventory, loader, path, cache)
        self.inventory.add_group('k8s_cluster')
        k8s_cluster_children_groups = ['etcd',
                                       'kube_control_plane',
                                       'kube_node',
                                       'nova_compute_nodes',
                                       'openstack_control_plane',
                                       'ovn_network_nodes',
                                       'storage_nodes',
                                       'ceph_storage_nodes',
                                       'cinder_storage_nodes']
        for group in k8s_cluster_children_groups:
            self.inventory.add_group(group)

        # cluster_name = 'cluster.local'
        # mgmt_network = 'openstack-flex'
        servers = self.os_client.list_servers()
        for server in servers:
            if 'role' in server.metadata:
                role = server.metadata['role']
                if role == 'controller':
                    for group in ['etcd',
                                  'kube_control_plane',
                                  'ovn_network_nodes',
                                  'openstack_control_plane']:
                        self.inventory.add_host(server.name, group)
                if role == 'compute':
                    self.inventory.add_host(server.name, 'nova_compute_nodes')
                if role == 'storage`':
                    self.inventory.add_host(server.name, 'storage_nodes')


def inventory_data(servers):
    """WIP Try using InventoryData Class"""
    inventory = InventoryData()
    inventory.add_group('k8s_cluster')
    k8s_cluster_children_groups = ['etcd',
                                   'kube_control_plane',
                                   'kube_node',
                                   'nova_compute_nodes',
                                   'openstack_control_plane',
                                   'ovn_network_nodes',
                                   'storage_nodes',
                                   'ceph_storage_nodes',
                                   'cinder_storage_nodes']
    for group in k8s_cluster_children_groups:
        inventory.add_group(group)

    for server in servers:
        ip_address = server['addresses']['osflex-mgmt'][0]['addr']
        host = Host(server.name)
        host.vars = {'ansible_host': ip_address, 'ip': "'{{ ansible_host }}'"}
        if 'role' in server.metadata:
            role = server.metadata['role']
            if role == 'controller':
                for group in ['etcd',
                              'kube_control_plane',
                              'ovn_network_nodes',
                              'openstack_control_plane']:
                    inventory.add_host(host.name, group)
            if role == 'compute':
                inventory.add_host(host.name, 'nova_compute_nodes')
            if role == 'storage`':
                inventory.add_host(host.name, 'storage_nodes')
    return inventory


class LabInventory:
    """A class to load lab inventory for kubespray"""

    def __init__(self) -> None:
        self.inventory = {'_meta': {'hostvars': {}}}
        self.launcher_floating_ip = None
        for group in ['all', 'k8s_cluster', 'flex_launcher']:
            self.add_group(group)
            if group == 'all':
                self.inventory['all'].update({'vars': {}})
                continue
            self.add_child_group('all', group)
        self.__init_k8s_cluster_child_groups()

    def __init_k8s_cluster_child_groups(self):
        """Help method to initialize k8s_cluster child groups"""
        groups = ['etcd',
                  'kube_control_plane',
                  'kube_node',
                  'nova_compute_nodes',
                  'openstack_control_plane',
                  'ovn_network_nodes',
                  'storage_nodes']
        for group in groups:
            self.add_group(group)
            self.add_child_group('k8s_cluster', group)

    def add_group(self, group: str) -> bool:
        """Adds group to inventory """
        if group not in self.inventory:
            self.inventory.update({group: {'children': [], 'hosts': [], 'vars': {}}})
        return True

    def add_child_group(self, parent: dict, child: str) -> bool:
        """ Adds a child group to an inventory group"""
        self.inventory[parent]['children'].append(child)

    def add_host_to_group(self, host: str, group: str) -> bool:
        """ Adds host to specified inventory group"""
        self.inventory[group]['hosts'].append(host)
        return True

    def add_host_to_hostvars(self, server):
        """Adds server to hostvars"""
        server_ip = server['addresses']['osflex-mgmt'][0]['addr']
        self.inventory['_meta']['hostvars'].update({server.name: {'ansible_host': server_ip,
                                                                  'ip': server_ip}})

    def add_vars_to_group(self, group, ansible_var: dict) -> None:
        """Adds vars to specified group"""
        self.inventory[group]['vars'].update(ansible_var)

    def get_floating_ip_from_server(self, server: Type[openstack.compute.v2.server.Server]) -> str:
        """Gets the floating ip from server.  It will return the first one or none"""
        for item in server['addresses']['osflex-mgmt']:
            if item['OS-EXT-IPS:type'] == 'floating':
                return item['addr']
        return None

    def parse_servers_from_openstack(self, servers: list) -> bool:
        """Adds list of servers from openstack to inventory"""
        ansible_ssh_vars = None
        servers = sorted(servers, key=lambda x: x.name)
        roles=set()
        for server in servers:
            if 'role' in server.metadata:
                roles.add(server.metadata['role'])
        for server in servers:
            if 'role' in server.metadata:
                # logger.info(f'processing {server.name}')
                role = server.metadata['role']
                self.add_host_to_hostvars(server)
                # do not add flex launcher to kube nodes
                if role != 'flex-launcher':
                    self.add_host_to_group(server.name, 'kube_node')
                if role == 'kubernetes':
                    self.add_host_to_group(server.name, 'kube_control_plane')
                if role == 'network':
                    self.add_host_to_group(server.name, 'ovn_network_nodes')
                if role == 'etcd':
                    self.add_host_to_group(server.name, 'etcd')
                if role == 'controller':
                    self.add_host_to_group(server.name, 'openstack_control_plane')
                    if 'etcd' not in roles:
                        self.add_host_to_group(server.name, 'etcd')
                    if 'kubernetes' not in roles:
                        self.add_host_to_group(server.name, 'kube_control_plane')
                    if 'network' not in roles:
                        self.add_host_to_group(server.name, 'ovn_network_nodes')
                if role == 'compute':
                    self.add_host_to_group(server.name, 'nova_compute_nodes')
                if role == 'storage':
                    self.add_host_to_group(server.name, 'storage_nodes')
                if role == 'flex-launcher':
                    self.add_host_to_group(server.name, 'flex_launcher')
                    self.launcher_floating_ip = self.get_floating_ip_from_server(server)
                    ansible_ssh_vars = f"-o StrictHostKeyChecking=no -o ProxyCommand='ssh -W %h:%p -q {self.launcher_floating_ip}'"  # pylint: disable=line-too-long.
        self.add_vars_to_group('all', {'ansible_ssh_common_args': ansible_ssh_vars})
        self.add_vars_to_group('all', {'ansible_forks': 25})
        self.add_vars_to_group('k8s_cluster', {'kube_ovn_default_interface_name': 'enps40'})
        self.add_vars_to_group('k8s_cluster', {'kube_ovn_iface': 'enps40'})
        self.add_vars_to_group('k8s_cluster', {'kube_ovn_central_hosts': self.inventory['ovn_network_nodes']['hosts']})  # pylint: disable=line-too-long.

    def json(self) -> str:
        """Returns json representation of inventory"""
        return json.dumps(self.inventory)

    def yaml_dump(self) -> None:
        """Prints yaml to stdout"""
        yaml = YAML(typ='safe')
        data = self.inventory
        data['hosts'] = data['_meta']['hostvars']
        del data['_meta']
        yaml.dump(data, sys.stdout)

def main(args):
    """The main function"""
    os_client = openstack.connect(args.cloud)
    servers = os_client.list_servers()
    inventory = LabInventory()
    inventory.parse_servers_from_openstack(servers)
    if args.yaml is True:
        inventory.yaml_dump()
    else:
        print(inventory.json())


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--cloud',
                        default=getenv('OS_CLOUD'),
                        help='The openstack cloud from clouds.yaml. Defaults to OS_CLOUD env variable')  # pylint: disable=line-too-long.
    parser.add_argument('--list',
                        action='store_true')
    parser.add_argument('--yaml', action='store_true')
    args = parser.parse_args()
    main(args)
