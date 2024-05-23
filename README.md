## openstack-flex-lab
I am using opentofu but I call it terraform alot still :/

### requirements

- A python virtual environment
- Install opentofu
- Install openstackclient
- Configure $HOME/.config/openstack/clouds.yaml with credentials

### python virtual environment
For later use of they dynamic inventory script a python virtual environment is needed. Create your virtual environment the way you see fit and install the requirements.

```bash
pip isntall -r requirements.txt
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
  rxt-dfw-example:
    # note: $YOUR_PROJECT is the account DDI with Flex, so XXXXXXX_Flex
    auth:
      auth_url: https://keystone.dfw-ospcv2-staging.ohthree.com/v3
      project_name: < DDI >_Flex # $YOUR_PROJECT
      project_domain_name: rackspace_cloud_domain
      username: < CLOUD USERNAME >
      password: < CLOUD PASSWORD >
      user_domain_name: rackspace_cloud_domain
    region_name: DFW3
    interface: public
    identity_api_version: "3"
    insecure: true
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

### Populate `/etc/hosts` in your cluster and put inventory on the launcher node
An ansible playbook along with a dynamic inventory script will populate the `/etc/hosts` file and drop the `/etc/genestack/inventory/inventory.yaml` file on the launcher node.

```bash
OS_CLOUD=rxt-sjc-servers2nd ansible-playbook -i scripts/lab_inventory.py scripts/playbooks/prepare_for_kubespray.yaml -u ubuntu
```

### time for kubespray
Log into your launcher node and follow the instructions at https://docs.rackspacecloud.com/genestack-getting-started/