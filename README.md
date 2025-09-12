# openstack-flex-lab

I am using opentofu but I call it terraform alot still :/

This builds out a lab environment as described at https://docs.rackspacecloud.com/ in an already available openstack endpoint. Once tofu has completed you can follow the steps in the linked documentation.

## requirements

- A python virtual environment
- Install opentofu
- Install openstackclient
- Configure $HOME/.config/openstack/clouds.yaml with credentials

## python virtual environment

For later use of they dynamic inventory script and ansible a python virtual environment is needed. Create your virtual environment the way you see fit and install the requirements.

```bash
pip install -r requirements.txt
```

## tofu

Opentofu or terraform is needed to build out the lab environment in an openstack deployment. Installation instructions for opentofu can be found at [opentofu docs](https://opentofu.org/docs/intro/install/).

Installing opentofu on a mac:

```bash
brew install opentofu
```

> **ℹ️ Info:** If you encountered the following error on M1 or M2 MacBook you need to follow the steps provided below and use terraform instead of tofu

```bash
│ Error: Incompatible provider version
│
│ Provider registry.opentofu.org/hashicorp/template v2.2.0 does not have a package available for your current platform, darwin_arm64.
│
│ Provider releases are separate from OpenTofu CLI releases, so not all providers are available for all platforms. Other versions of this provider may have different platforms supported.
```

> steps to resolve the issue:

```bash
brew install kreuzwerker/taps/m1-terraform-provider-helper
m1-terraform-provider-helper install hashicorp/template -v v2.2.0
m1-terraform-provider-helper activate
terraform init --upgrade
```

At this point you can plan if you want to see what will be done but ultimatelay you will need to `apply`.  There are two requried variables to be passed:

### Cloud endpoint

As mentioned before you need an `$HOME/.config/openstack/clouds.yaml` file configured with an openstack cloud you intend to deploy your lab in.  This cloud is not the region cloud but one that can be used with a rackspace ddi.  Example:

```yaml
clouds:
  rxt-sjc-example:
    # note: $YOUR_PROJECT is the account DDI with Flex, so XXXXXXX_Flex
    auth:
      auth_url: https://keystone.api.sjc3.rackspacecloud.com/v3
      project_name: < YOUR PROJECT NAME>
      project_domain_name: rackspace_cloud_domain
      username: < CLOUD USERNAME >
      password: < CLOUD PASSWORD>
      user_domain_name: rackspace_cloud_domain
    region_name: < REGION NAME >
    interface: public
    identity_api_version: "3"
    insecure: true
```

Once you have opentofu installed initialize it so that required plugins are installed

```bash
tofu init --upgrade
```

At the very minimum you will need to provide  tofu the name of the cloud you are going to use as well as an ssh key for connecting into the launcher instance. This can be provided on the command line like:

```bash
tofu apply -var "cloud=< CLOUD NAME>" -var "ssh_public_key_path=~/.ssh/id_rsa.pub"
```

Adding all of the variables on the command line get get onerous. Tofu provides a mechanism to set variables in the `terraform.tfvars` file.

```hcl
cloud="CLOUD NAME"
ssh_public_key_path="~/.ssh/id_rsa.pub"
```

With the variables setup in the `terraform.tfvars` file standing up the environment is as simple as:

```bash
tofu apply
```

### Customizing your lab

The defaults setup a reasonably sized small environment to use for testing and
development. The [variables.tf](variables.tf) contain the variables available
for use. Using the file `terraform.tfvars` file will allow you to specify
additional variables to customize the environment that is created. For example,
you may only want to have three worker nodes and no storage nodes in the
environment. This can be achieved with the following `terraform.tfvars` file.

```hcl
cloud="mycloud"
ssh_public_key_path="~/.ssh/id_rsa.pub"
worker_count=3
storage_count=0
```

### plan/apply

Now that the `terraform.tfvars` file is setup the environment can be built:

```bash
tofu plan
tofu apply
```

Once you `apply` the tofu config you will be given the floating address of your
launcher node.

## ssh config to use the gateway

Once you have deployed the infra, its time to set your private key and use it to connect through the gateway. Add the following to `$HOME/.ssh/config`

```bash
Host <YOUR_LAUNCHER_NODE_IP_RANGE>
  User ubuntu
  IdentityFile ~/.ssh/id_rsa
  ProxyCommand ssh -A gu=<YOUR_USERNAME>@ubuntu@%h@<GATEWAY_ADDRESS> nc %h %p
  ForwardAgent yes
  ForwardX11Trusted yes
  ProxyCommand none
  ControlMaster auto
  ControlPath ~/.ssh/master-%r@%h:%p
  TCPKeepAlive yes
  StrictHostKeyChecking no
  ServerAliveInterval 300
```

## Prepare for kubespray

The `prepare_for_kubespray.yaml` playbook as the name implies prepare the launcher node to run kubespray.  Inventory based on tofu/terraform, the `genestack_post_deploy.yaml` playbook and helper scripts are all copied to the launcher node.

```bash
OS_CLOUD=rxt-sjc-example ansible-playbook -i scripts/lab_inventory.py scripts/playbooks/prepare_for_kubespray.yaml -u ubuntu
```

### time for kubespray

The steps here closely follow the instructions at [genestack getting started](https://docs.rackspacecloud.com/genestack-getting-started/).

From here log into the launcher node to complete the deploy

```bash
source /opt/genestack/scripts/genestack.rc
ansible -m shell -a 'hostnamectl set-hostname {{ inventory_hostname }}' --become all
ansible -m shell -a "grep 127.0.0.1 /etc/hosts | grep -q {{ inventory_hostname }} || sed -i 's/^127.0.0.1.*/127.0.0.1 {{ inventory_hostname }} localhost.localdomain localhost/' /etc/hosts" --become all
cd /opt/genestack/ansible/playbooks && ansible-playbook host-setup.yml
cd /opt/genestack/submodules/kubespray && sudo -E /home/ubuntu/.venvs/genestack/bin/ansible-playbook cluster.yml -b -f 30 -T 30 -u ubuntu
```

The kubespray deploy commonly takes about 30 minutes or so.  Once it is finished a helper script is in place to copy the kubeconfig to the launcher node:

```bash
get_kube_config.sh
```

## Deploying GeneStack

You need to follow the [GeneStack doc](https://docs.rackspacecloud.com/openstack-overview/) from this point.
