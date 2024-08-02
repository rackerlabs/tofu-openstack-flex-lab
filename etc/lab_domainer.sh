#!/bin/bash

usage() {
    echo "Adds your custom DNS domain, and desired environment (region) name for keystone to helm overrides"
    echo "Usage: $0 --domain <domain> [--environment <environment> default: LAB1]"
    exit 1
}

domain=""
environment="LAB1"

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --domain)
            domain="$2"
            shift 2
            ;;
        --environment)
            environment="$2"
            shift 2
            ;;
        *)
            echo "Unknown parameter passed: $1"
            usage
            ;;
    esac
done

# Check if the domain argument is provided
if [ -z "$domain" ]; then
    usage
fi

# Replace your.domain.tld with the provided domain value
find helm-configs/. -type f -exec sed --debug -i "s/your.domain.tld/$domain/g" {} \;

# Replace LAB1 env with the provided env instead
if [ "$environment" != "LAB1" ]; then
  find helm-configs/. -type f -exec sed --debug -i "s/LAB1/$environment/g" {} \;
fi

echo "Replacements complete."
