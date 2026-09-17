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

echo "Installing metrics-server..."
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# EKS kubelets serve their metrics endpoint with a self-signed certificate,
# which metrics-server rejects by default - needs --kubelet-insecure-tls.
# Guarded so re-running this script doesn't keep appending the flag.
if ! kubectl get deployment metrics-server -n kube-system -o jsonpath='{.spec.template.spec.containers[0].args}' | grep -q "kubelet-insecure-tls"; then
  kubectl patch deployment metrics-server -n kube-system --type=json \
    -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'
fi

kubectl wait --for=condition=available --timeout=5m deployment/metrics-server -n kube-system
kubectl get pods -n kube-system | grep metrics-server

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

# `helm upgrade` regenerates the webhook's self-signed cert every run, but
# won't restart pods that don't otherwise need it - leaving them serving a
# stale cert that no longer matches the webhook's registered CA bundle.
# That breaks creation of ANY Service/Pod cluster-wide until they restart.
echo "Restarting AWS Load Balancer Controller to pick up its webhook certificate..."
kubectl rollout restart deployment/aws-load-balancer-controller -n kube-system
kubectl rollout status deployment/aws-load-balancer-controller -n kube-system --timeout=5m
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

echo "Setting up shared ALB (sharedlbs namespace + bootstrap Ingress)..."
kubectl apply -f "$REPO_DIR/k8s/sharedlbs/namespace.yaml"
kubectl apply -f "$REPO_DIR/k8s/sharedlbs/dummy-service.yaml"

echo "Generating self-signed wildcard certificate for the shared ALB..."
cat <<'EOF' | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: shared-alb-cert
  namespace: sharedlbs
spec:
  secretName: shared-alb-tls
  issuerRef:
    name: selfsigned-issuer
    kind: ClusterIssuer
  commonName: "*.internal.crud-devops-pipeline.local"
  dnsNames:
    - "*.internal.crud-devops-pipeline.local"
EOF

kubectl wait --for=condition=Ready certificate/shared-alb-cert -n sharedlbs --timeout=2m

kubectl get secret shared-alb-tls -n sharedlbs -o jsonpath='{.data.tls\.crt}' | base64 -d > /tmp/shared-alb.crt
kubectl get secret shared-alb-tls -n sharedlbs -o jsonpath='{.data.tls\.key}' | base64 -d > /tmp/shared-alb.key

echo "Importing certificate into ACM (updating in place if it already exists)..."
EXISTING_CERT_ARN=$(aws acm list-certificates --region "$AWS_REGION" \
  --query "CertificateSummaryList[?DomainName=='*.internal.crud-devops-pipeline.local'].CertificateArn" \
  --output text)

if [ -n "$EXISTING_CERT_ARN" ]; then
  echo "Updating existing ACM certificate: $EXISTING_CERT_ARN"
  ACM_CERT_ARN=$(aws acm import-certificate \
    --certificate-arn "$EXISTING_CERT_ARN" \
    --certificate fileb:///tmp/shared-alb.crt \
    --private-key fileb:///tmp/shared-alb.key \
    --region "$AWS_REGION" \
    --query CertificateArn --output text)
else
  echo "Importing new ACM certificate"
  ACM_CERT_ARN=$(aws acm import-certificate \
    --certificate fileb:///tmp/shared-alb.crt \
    --private-key fileb:///tmp/shared-alb.key \
    --region "$AWS_REGION" \
    --query CertificateArn --output text)
fi
rm -f /tmp/shared-alb.crt /tmp/shared-alb.key
echo "ACM_CERT_ARN=$ACM_CERT_ARN"

ALB_LOGS_BUCKET=$(cd "$REPO_DIR/infra/environments/dev/addons" && terraform init -input=false > /dev/null && terraform output -raw alb_logs_bucket)
echo "ALB_LOGS_BUCKET=$ALB_LOGS_BUCKET"

echo "Applying shared ALB bootstrap Ingress..."
sed -e "s|\${ACM_CERT_ARN}|$ACM_CERT_ARN|g" -e "s|\${ALB_LOGS_BUCKET}|$ALB_LOGS_BUCKET|g" \
  "$REPO_DIR/k8s/sharedlbs/ingress.yaml.tpl" | kubectl apply -f -

echo "Waiting for the shared ALB to provision..."
for i in {1..30}; do
  SHARED_ALB=$(kubectl get ingress crud-eksshared-001 -n sharedlbs -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)
  if [ -n "$SHARED_ALB" ]; then
    echo "Shared ALB address: $SHARED_ALB"
    break
  fi
  sleep 10
done

echo "Setting up a second, dedicated ALB group for the nginx test app..."
kubectl apply -f "$REPO_DIR/k8s/sharedlbs/nginx-ingress.yaml"

# The nginx test app itself (namespace, deployment, service, ingress) is NOT
# applied here - it's a real application, so it's deployed via ArgoCD like
# crud-backend, not kubectl-applied by this bootstrap script. See
# k8s/argocd/application-nginx.yaml.

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

echo "Waiting for ArgoCD to create the pruebas-cni namespace..."
for i in {1..30}; do
  if kubectl get namespace pruebas-cni &> /dev/null; then
    echo "Namespace pruebas-cni exists"
    break
  fi
  sleep 10
done

kubectl wait --for=condition=available --timeout=5m deployment/nginx-test -n pruebas-cni
kubectl get pods -n pruebas-cni

echo "Verifying ArgoCD syncs..."
kubectl get applications -n argocd
kubectl get pods -n dev
kubectl get pods -n pruebas-cni
