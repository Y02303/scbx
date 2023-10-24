## Install Terraform
```
brew install terraform
```

## Install Azure CLI
```
brew update && brew install azure-cli
```

## Sign in with Azure CLI
```
az login
```

## Generate key pair
```
ssh-keygen -f mykey
```

## Initialize Terraform configuration
```
terraform init
terraform plan
```

## Deploy
```
terraform apply -auto-approve
```

## Destroy
```
terraform destroy -auto-approve
```