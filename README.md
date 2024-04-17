## openstack-flex-lab


```bash
tofu plan -var "cloud=<CLOUD NAME IN clouds.yaml>" -var "ssh_public_key_path=~/.ssh/id_rsa.pub"
```

### get your floating ip for launcher node after terraform apply
```bash
openstack --os-cloud <CLOUD NAME IN clouds.yaml> floating ip list
```
