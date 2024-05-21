#!/usr/bin/env bash

if [ ! -d genestack ]; then 
    git clone --recurse-submodules -j4 git@github.com:cblument/genestack.git
fi
pushd genestack
if ! git ls-remote --exit-code upstream >/dev/null 2>&1; then
    git remote add upstream git@github.com:rackerlabs/genestack.git
fi
popd
cp scripts/lab_inventory.py genestack/scripts/lab_inventory.py
# echo "openstack-flex" > genestack/etc/genestack/product

