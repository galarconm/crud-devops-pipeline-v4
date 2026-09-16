# Runbook de despliegue — rama `feature/enterprise-networking`

Pasos reales, probados, para levantar y destruir esta infraestructura. El cluster EKS es **100% privado**
(`endpoint_public_access = false`), así que todo lo que necesita `kubectl`/`helm` tiene que correr desde
una **CloudShell asociada a la VPC**, no desde una terminal local ni desde un runner de GitHub Actions.

## Prerrequisitos

- AWS CLI configurado con el usuario `Admin` (`aws sts get-caller-identity` debe devolver ese usuario —
  quien corre `terraform apply` sobre la capa `eks` queda automáticamente como admin del cluster nuevo).
- Terraform instalado en tu máquina local.
- Rama pusheada a `origin` (`git push -u origin feature/enterprise-networking` si es la primera vez).

## 1. Desplegar

### 1.1 Infraestructura base (Terraform, desde tu terminal local)

Orden real por dependencias entre states (`eks` necesita el `secret_arn` que expone `data`):

```bash
cd infra/environments/dev/networking && terraform init && terraform apply -auto-approve
cd ../data && terraform init && terraform apply -auto-approve
cd ../eks && terraform init && terraform apply -auto-approve
```

`tgw` no depende de nada más que `networking` — podés aplicarlo en paralelo con `data`/`eks`, o después:

```bash
cd infra/environments/dev/tgw && terraform init && terraform apply -auto-approve
```

### 1.2 Generar (sin aplicar del todo) el `ENIConfig` para VPC CNI

**Importante:** no corras el `apply` completo de `addons` todavía. Si lo hacés antes de que el `ENIConfig`
exista en el cluster, `vpc-cni` y `ebs-csi`/`efs-csi` se quedan colgados en `CREATING` hasta el timeout de
20 minutos y fallan (el CNI con custom networking activado no puede inicializar sin el `ENIConfig`, y como
es el plugin de red del cluster, bloquea a todos los demás pods también).

```bash
cd infra/environments/dev/addons
terraform init
terraform apply -target=local_file.eniconfig -auto-approve
cat generated/eniconfig.yaml   # copiá este contenido, lo necesitás en el paso 1.4
```

### 1.3 Armar la CloudShell (VPC environment)

Los IDs cambian en cada despliegue — consultalos así:

```bash
aws ec2 describe-vpcs --region us-east-1 --filters "Name=tag:Name,Values=crud-devops-pipeline-dev-vpc" --query "Vpcs[0].VpcId" --output text
aws ec2 describe-subnets --region us-east-1 --filters "Name=tag:Name,Values=crud-devops-pipeline-dev-middleware-subnet-1" --query "Subnets[0].SubnetId" --output text
aws ec2 describe-security-groups --filters "Name=group-name,Values=crud-devops-pipeline-dev-eks-nodes-sg" --region us-east-1 --query "SecurityGroups[0].GroupId" --output text
```

En la consola de AWS: **CloudShell → ⚙️ → Create VPC environment** → elegí esa VPC, esa subred
(`middleware`), y ese Security Group (`eks-nodes-sg` — se "presta" porque el SG del control plane ya
confía en él para el puerto 443; no hace falta crear un SG dedicado para esto).

### 1.4 Desde la CloudShell: conectar y aplicar el `ENIConfig`

```bash
git clone -b feature/enterprise-networking https://github.com/galarconm/crud-devops-pipeline-v4.git ~/crud-devops-pipeline-v4
cd ~/crud-devops-pipeline-v4

aws sts get-caller-identity                # confirmá que sea Admin
aws eks update-kubeconfig --name crud-devops-pipeline-dev --region us-east-1
kubectl get nodes                          # debería responder sin pedir credenciales

cat > eniconfig.yaml <<'EOF'
# pegá acá el contenido que copiaste en el paso 1.2
EOF
kubectl apply -f eniconfig.yaml
kubectl get eniconfig                      # deberías ver us-east-1a y us-east-1b
```

### 1.5 Completar el apply de `addons` (desde tu terminal local)

```bash
cd infra/environments/dev/addons
terraform apply -auto-approve
aws eks list-addons --cluster-name crud-devops-pipeline-dev --region us-east-1   # los 4 deben quedar ACTIVE
```

### 1.6 Bootstrap de ArgoCD + LBC + ExternalDNS + cert-manager (desde la CloudShell)

```bash
cd ~/crud-devops-pipeline-v4
./bootstrap.sh
```

Es idempotente (usa `helm upgrade --install`) — si algo falla a mitad de camino, corregís y volvés a
correr el script completo sin problema.

### 1.7 Verificar

```bash
kubectl get ingress -n dev            # la columna ADDRESS debe mostrar un DNS internal-...
kubectl get applications -n argocd    # crud-backend debe quedar Synced
```

## 2. Destruir

**No lo hagas al revés de esto** — el ALB y el registro DNS los crean los controllers (LBC/ExternalDNS)
directamente en AWS, **no Terraform**. Si destruís el cluster sin borrarlos primero: el ALB queda
huérfano en AWS (sigue facturando, invisible para Terraform), y el `terraform destroy` de `addons` puede
fallar porque AWS no deja borrar una hosted zone de Route53 que todavía tiene registros adentro.

### 2.1 Limpiar los recursos que crearon los controllers (desde la CloudShell, con el cluster vivo)

**No borres el `Ingress` directamente** — el `Application` de ArgoCD tiene `selfHeal: true`, así que en
cuanto lo borrás, ArgoCD ve que "falta" (sigue existiendo en `k8s/base/` en git) y lo vuelve a crear. Hay
que borrar el `Application` en sí, que tiene el finalizer `resources-finalizer.argocd.argoproj.io`: eso
hace que ArgoCD borre en cascada todo lo que gestiona (Ingress incluido, esperando a que el LBC termine de
desmantelar el ALB real en AWS) antes de terminar de borrarse a sí mismo.

```bash
kubectl delete application crud-backend -n argocd
```

Este comando espera (puede tardar 1-3 min, por la cascada de finalizers) antes de devolver el control —
es seguro cortarlo con `Ctrl+C`, la limpieza del lado de AWS sigue corriendo igual. Confirmá que terminó:

```bash
aws elbv2 describe-load-balancers --region us-east-1 --query "LoadBalancers[].LoadBalancerName" --output text
# debe devolver vacío antes de seguir
```

### 2.2 Destruir la infraestructura (desde tu terminal local)

```bash
cd infra/environments/dev/addons && terraform destroy -auto-approve
cd ../eks && terraform destroy -auto-approve
cd ../tgw && terraform destroy -auto-approve
cd ../data && terraform destroy -auto-approve
cd ../networking && terraform destroy -auto-approve
```

### 2.3 Verificar que no quedó nada corriendo

```bash
aws eks list-clusters --region us-east-1
aws rds describe-db-instances --region us-east-1 --query "DBInstances[].DBInstanceIdentifier"
aws efs describe-file-systems --region us-east-1 --query "FileSystems[].FileSystemId"
aws ec2 describe-nat-gateways --region us-east-1 --filter "Name=state,Values=available,pending" --query "NatGateways[].NatGatewayId"
aws ec2 describe-transit-gateways --region us-east-1 --filters "Name=state,Values=available,pending" --query "TransitGateways[].TransitGatewayId"
aws elbv2 describe-load-balancers --region us-east-1 --query "LoadBalancers[].LoadBalancerName"
```

Todos deben devolver vacío.

## Notas / gotchas conocidos

- `run.sh`/`destroy.sh` (raíz del repo) hacen `networking → data → eks → addons` en ese orden, pero
  **no incluyen `tgw`** — hay que aplicarlo/destruirlo aparte siempre. Tampoco respetan la secuencia del
  `ENIConfig` del paso 1.2/1.4, así que si los usás tal cual, es esperable que `addons` falle la primera
  vez — volvé a correr `terraform apply` en esa capa después de aplicar el `ENIConfig`.
- Los `Application` de ArgoCD (`k8s/argocd/*.yaml`) apuntan a `targetRevision: feature/enterprise-networking`,
  no a `main`. Si mergeás esta rama a `main` en algún momento, actualizá ese campo (o ArgoCD va a seguir
  desplegando desde la rama vieja).
- El `Ingress` de la app (`k8s/base/ingress.yaml`) debe usar `alb.ingress.kubernetes.io/scheme: internal`.
  No hay subredes públicas multi-AZ en este diseño (a propósito, arquitectura 100% interna) — un
  `internet-facing` nunca va a poder aprovisionar el ALB.
- La instalación del AWS Load Balancer Controller vía Helm regenera su certificado TLS del webhook en
  cada `helm upgrade` sin reiniciar los pods necesariamente — `bootstrap.sh` ya incluye un
  `kubectl rollout restart` automático después de instalarlo/actualizarlo para evitar que esto rompa la
  creación de cualquier Service/Pod nuevo en el cluster.
