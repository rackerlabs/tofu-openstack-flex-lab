## openstack-flex-lab
I am using opentofu but I call it terraform alot still :/

### requirements

- Install opentofu
- Install openstackclient
- Configure $HOME/.config/openstack/clouds.yaml with credentials

### initialize tofu
```bash
tofu init --upgrade
```

### plan/apply
```bash
tofu plan -var "cloud=<CLOUD NAME IN clouds.yaml>" -var "ssh_public_key_path=~/.ssh/id_rsa.pub"
tofu apply -var "cloud=<CLOUD NAME IN clouds.yaml>" -var "ssh_public_key_path=~/.ssh/id_rsa.pub"
```

### get your floating ip for launcher node after terraform apply
```bash
openstack --os-cloud <CLOUD NAME IN clouds.yaml> floating ip list
```
