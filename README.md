## openstack-flex-lab
I am using opentofu but I call it terraform alot still :/

This builds out a lab environment as described at https://docs.rackspacecloud.com/ in an already available openstack endpoint. Once tofu has completed you can follow the steps in the linked documentation.

### requirements

- A python virtual environment
- Install opentofu
- Install openstackclient
- Configure $HOME/.config/openstack/clouds.yaml with credentials

### python virtual environment
For later use of they dynamic inventory script a python virtual environment is needed. Create your virtual environment the way you see fit and install the requirements.

```bash
pip install -r requirements.txt
```

### tofu
Opentofu or terraform is needed to build out the lab environment in an openstack deployment. Installation instructions for opentofu can be found [here](https://opentofu.org/docs/intro/install/).

Installing opentofu on a mac:
```bash
brew install opentofu
```

Once you have opentofu installed initialize it so that required plugins are installed
```bash
tofu init --upgrade
```
At this point you can plan if you want to see what will be done but ultimatelay you will need to `apply`.  There are two requried variables to be passed:

- `cloud`

As mentioned before you need an `$HOME/.config/openstack/clouds.yaml` file configured with an openstack cloud you intend to deploy your lab in.  This cloud is not the region cloud but one that can be used with a rackspace ddi.  Example:

```yaml
clouds:
  rxt-sjc-example:
    # note: $YOUR_PROJECT is the account DDI with Flex, so XXXXXXX_Flex
    auth:
      auth_url: https://keystone.api.sjc3.rackspacecloud.com/v3
      project_name: < DDI >_Flex # $YOUR_PROJECT
      project_domain_name: rackspace_cloud_domain
      username: < CLOUD USERNAME >
      password: < CLOUD PASSWORD>
      user_domain_name: rackspace_cloud_domain
    region_name: SJC3
    interface: public
    identity_api_version: "3"
    insecure: true
```

- `ssh_public_key_path`

The ssh public key path is added to openstack and is required for ssh agent forwarding to be setup.  Specify the path to your public key and you will be good to go.

### plan/apply
```bash
tofu plan -var "cloud=<CLOUD NAME IN clouds.yaml>" -var "ssh_public_key_path=~/.ssh/id_rsa.pub"
tofu apply -var "cloud=<CLOUD NAME IN clouds.yaml>" -var "ssh_public_key_path=~/.ssh/id_rsa.pub"
```

Once you `apply` the tofu config you will be given the ip address of your launcher node.  Also thanks to @luke8738 and some fancy cloudinit configs the launcher nodes has what you need isntalled and you are automatically in the genestack virtualenv.  Log into the launcher node and `cat /etc/motd` for details. 

### Prepare for kubespray

The `prepare_for_kubespray.yaml` playbook as the name implies prepare the launcher node to run kubespray.  Inventory based on tofu/terraform, the `genestack_post_deploy.yaml` playbook and helper scripts are all copied to the launcher node.

```bash
OS_CLOUD=rxt-sjc-example ansible-playbook -i scripts/lab_inventory.py scripts/playbooks/prepare_for_kubespray.yaml -u ubuntu
```

### time for kubespray

The steps here closely follow the instructions at [genestack getting started](https://docs.rackspacecloud.com/genestack-getting-started/).

From here log into the launcher node to complete the deploy
```
ansible -m shell -a 'hostnamectl set-hostname {{ inventory_hostname }}' --become all
ansible -m shell -a "grep 127.0.0.1 /etc/hosts | grep -q {{ inventory_hostname }} || sed -i 's/^127.0.0.1.*/127.0.0.1 {{ inventory_hostname }} localhost.localdomain localhost/' /etc/hosts" --become all
cd /opt/genestack/ansible/playbooks && ansible-playbook host-setup.yml
cd /opt/genestack/submodules/kubespray && ansible-playbook cluster.yml -b -f 30 -T 30
```

The kubespray deploy commonly takes about 30 minutes or so.  Once it is finished a helper script is in place to copy the kubeconfig to the launcher node:

```
get_kube_config.sh
```

Now that the kubeconfig is in place run the `genestack_post_deploy.yaml` file as ubuntu in the ubuntu home directory.  It is best to provide the `letsencrypt_email` variable on the command line so the playbook does not stop and prompt you in the middle of the run.

```
ansible-playbook ~/genestack_post_deploy.yaml -e "letsencrypt_email=<VALID EMAIL ADDRESS"
```
