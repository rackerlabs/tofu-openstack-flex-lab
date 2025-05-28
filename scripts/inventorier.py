import argparse
import openstack
import yaml

parser = argparse.ArgumentParser()
parser.add_argument('os_cloud',
                    help='cloud to use from clouds.yaml openstack config file to generate inventory for')
args = parser.parse_args()

os = openstack.connect(args.os_cloud)

kubernetes_prefix = 'kubernetes'
network_prefix = 'network'
controller_prefix = 'controller'
worker_prefix = 'worker'
compute_prefix = 'compute'
storage_prefix = 'storage'
ceph_prefix = 'ceph'
cluster_name = 'cluster.local'
kube_ovn_iface = 'enp4s0'
mgmt_network = 'osflex-mgmt'

servers = os.list_servers()

hosts = sorted([
    (
        f'{host["name"]}.{cluster_name}'
        if cluster_name not in host["name"] else host["name"],
        host['addresses'][mgmt_network][0]['addr']
    ) for host in servers if
    host['name'].startswith(controller_prefix) or
    host['name'].startswith(worker_prefix) or
    host['name'].startswith(compute_prefix) or
    host['name'].startswith(storage_prefix) or
    host['name'].startswith(kubernetes_prefix) or
    host['name'].startswith(network_prefix) or
    host['name'].startswith(ceph_prefix)
], key=lambda x: x[0])

inventory = {
    'all': {
        'vars': {
            'ansible_ssh_common_args': '-o StrictHostKeyChecking=no'
        },
        'hosts': {
            host_ip_tuple[0]: {
                'ip': '{{ ansible_host }}',
                'ansible_host': host_ip_tuple[1]
            } for host_ip_tuple in hosts
        },
        'children': {'k8s_cluster': {
            'vars': {
                'cluster_name': cluster_name,
                'kube_ovn_iface': kube_ovn_iface,
                'kube_ovn_default_interface_name': kube_ovn_iface,
                'kube_ovn_central_hosts':
                    '{{ groups["ovn_network_nodes"] }}'},
            'children': {
                'kube_control_plane': {'hosts': {
                    host[0]: None
                    for host in hosts if host[0].startswith(kubernetes_prefix)
                }},
                'etcd': {'hosts': {
                    host[0]: None
                    for host in hosts if host[0].startswith(kubernetes_prefix)
                }},
                'kube_node': {'hosts': {
                    host[0]: None
                    for host in hosts if
                    host[0].startswith(kubernetes_prefix) or
                    host[0].startswith(controller_prefix) or
                    host[0].startswith(worker_prefix) or
                    host[0].startswith(compute_prefix) or
                    host[0].startswith(storage_prefix) or
                    host[0].startswith(ceph_prefix) or
                    host[0].startswith(network_prefix)
                }},
                'openstack_control_plane': {'hosts': {
                    host[0]: None
                    for host in hosts if host[0].startswith(controller_prefix)
                }},
                'ovn_network_nodes': {'hosts': {
                    host[0]: None
                    for host in hosts if host[0].startswith(network_prefix)
                }},
                'nova_compute_nodes': {'hosts': {
                    host[0]: None
                    for host in hosts if host[0].startswith(compute_prefix)
                }},
                'storage_nodes': {
                    'children': {
                        'ceph_storage_nodes': {'hosts': {
                            host[0]: None
                            for host in hosts if
                            host[0].startswith(ceph_prefix)
                        }},
                        'cinder_storage_nodes': {'hosts': {
                            host[0]: None
                            for host in hosts if
                            host[0].startswith(storage_prefix)
                        }}
                    }
                }
            }
        }}
    }
}

yaml_data = yaml.dump(inventory)
print(yaml_data)
