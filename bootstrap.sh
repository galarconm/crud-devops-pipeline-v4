#!/bin/bash
set -euo pipefail

# Bootstrap ArgoCD + AWS Load Balancer Controller onto the EKS cluster.
# Run this from a CloudShell session attached to the cluster's VPC (the
# cluster's API endpoint is private-only, so a regular shell or a
# GitHub-hosted CI runner can't reach it).

AWS_REGION="us-east-1"
EKS_CLUSTER_NAME="crud-devops-pipeline-dev"
REPO_DIR="$HOME/crud-devops-pipeline-v4"
TF_VERSION="1.12.2"

echo "Checking for required tools..."

if ! command -v terraform &> /dev/null; then
  echo "Installing Terraform ${TF_VERSION}..."
  curl -fsSL -o /tmp/terraform.zip "https://releases.hashicorp.com/terraform/${TF_VERSION}/terraform_${TF_VERSION}_linux_amd64.zip"
  unzip -o /tmp/terraform.zip -d /tmp
  sudo mv /tmp/terraform /usr/local/bin/terraform
  rm /tmp/terraform.zip
fi

if ! command -v helm &> /dev/null; then
  echo "Installing Helm..."
  curl -fsSL -o /tmp/get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
  chmod 700 /tmp/get_helm.sh
  /tmp/get_helm.sh
  rm /tmp/get_helm.sh
fi

echo "Configuring kubectl for cluster $EKS_CLUSTER_NAME..."
aws eks update-kubeconfig --name "$EKS_CLUSTER_NAME" --region "$AWS_REGION"

echo "Verifying cluster is healthy..."
NOTREADY=$(kubectl get nodes --no-headers | awk '$2 != "Ready"' | wc -l)
if [ "$NOTREADY" -gt 0 ]; then
  echo "ABORT: Cluster has $NOTREADY unhealthy nodes."
  kubectl get nodes
  exit 1
fi
echo "Cluster healthy - proceeding"

echo "Installing ArgoCD..."
kubectl create namespace argocd || true
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml \
  --server-side \
  --force-conflicts
kubectl wait --for=condition=available --timeout=5m deployment/argocd-server -n argocd
kubectl get pods -n argocd

echo "Installing AWS Load Balancer Controller..."
helm repo add eks https://aws.github.io/eks-charts
helm repo update

LBC_ROLE_ARN=$(cd "$REPO_DIR/infra/environments/dev/addons" && terraform init -input=false > /dev/null && terraform output -raw lbc_role_arn)
VPC_ID=$(cd "$REPO_DIR/infra/environments/dev/networking" && terraform init -input=false > /dev/null && terraform output -raw vpc_id)

echo "LBC_ROLE_ARN=$LBC_ROLE_ARN"
echo "VPC_ID=$VPC_ID"

helm upgrade --install aws-load-balancer-controller \
  eks/aws-load-balancer-controller \
  --namespace kube-system \
  --set clusterName="$EKS_CLUSTER_NAME" \
  --set serviceAccount.create=true \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set "serviceAccount.annotations.eks\.amazonaws\.com/role-arn=$LBC_ROLE_ARN" \
  --set region="$AWS_REGION" \
  --set vpcId="$VPC_ID"

kubectl wait --for=condition=available --timeout=5m deployment/aws-load-balancer-controller -n kube-system
kubectl get pods -n kube-system | grep aws-load-balancer-controller

echo "Installing ExternalDNS..."
helm repo add external-dns https://kubernetes-sigs.github.io/external-dns/
helm repo update

EXTERNAL_DNS_ROLE_ARN=$(cd "$REPO_DIR/infra/environments/dev/addons" && terraform init -input=false > /dev/null && terraform output -raw external_dns_role_arn)
EXTERNAL_DNS_ZONE_ID=$(cd "$REPO_DIR/infra/environments/dev/addons" && terraform output -raw external_dns_zone_id)
EXTERNAL_DNS_DOMAIN=$(cd "$REPO_DIR/infra/environments/dev/addons" && terraform output -raw external_dns_zone_name)
EXTERNAL_DNS_DOMAIN="${EXTERNAL_DNS_DOMAIN%.}" # Route53 zone names end in a trailing dot, domainFilters doesn't want it

echo "EXTERNAL_DNS_ROLE_ARN=$EXTERNAL_DNS_ROLE_ARN"
echo "EXTERNAL_DNS_ZONE_ID=$EXTERNAL_DNS_ZONE_ID"
echo "EXTERNAL_DNS_DOMAIN=$EXTERNAL_DNS_DOMAIN"

kubectl create namespace external-dns || true

helm upgrade --install external-dns external-dns/external-dns \
  --namespace external-dns \
  --set provider=aws \
  --set policy=sync \
  --set aws.zoneType=private \
  --set "domainFilters[0]=$EXTERNAL_DNS_DOMAIN" \
  --set "aws.zoneIds[0]=$EXTERNAL_DNS_ZONE_ID" \
  --set txtOwnerId="$EKS_CLUSTER_NAME" \
  --set serviceAccount.create=true \
  --set serviceAccount.name=external-dns \
  --set "serviceAccount.annotations.eks\.amazonaws\.com/role-arn=$EXTERNAL_DNS_ROLE_ARN"

kubectl wait --for=condition=available --timeout=5m deployment/external-dns -n external-dns
kubectl get pods -n external-dns

echo "Installing cert-manager..."
helm repo add jetstack https://charts.jetstack.io
helm repo update

helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --set installCRDs=true

kubectl wait --for=condition=available --timeout=5m deployment/cert-manager -n cert-manager
kubectl wait --for=condition=available --timeout=5m deployment/cert-manager-webhook -n cert-manager

# No real public domain to validate a DNS-01/ACME challenge against (the
# Route53 zone above is private), so a self-signed ClusterIssuer is the
# practical choice here instead of Let's Encrypt.
echo "Creating self-signed ClusterIssuer..."
cat <<'EOF' | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: selfsigned-issuer
spec:
  selfSigned: {}
EOF

kubectl get clusterissuer
kubectl get pods -n cert-manager

echo "Applying ArgoCD application manifests..."
kubectl apply -f "$REPO_DIR/k8s/argocd/"

echo "Waiting for ArgoCD to create the dev namespace..."
for i in {1..30}; do
  if kubectl get namespace dev &> /dev/null; then
    echo "Namespace dev exists"
    break
  fi
  sleep 10
done

kubectl wait --for=condition=available --timeout=5m deployment/crud-backend-deployment -n dev
kubectl get pods -n dev

echo "Verifying ArgoCD syncs..."
kubectl get applications -n argocd
kubectl get pods -n dev
