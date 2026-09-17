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

Esto también crea el bucket S3 para los access logs del ALB compartido (`modules/eks-addons/alb-logs.tf`).

### 1.6 Bootstrap completo (desde la CloudShell)

```bash
cd ~/crud-devops-pipeline-v4
./bootstrap.sh
```

Es idempotente (usa `helm upgrade --install`) — si algo falla a mitad de camino, corregís y volvés a
correr el script completo sin problema. En orden, instala/crea:

1. ArgoCD
2. `metrics-server` (con `--kubelet-insecure-tls`, necesario en EKS) — sin esto, cualquier `HPA` se queda
   con `TARGETS: <unknown>` y ArgoCD marca la app entera como `Degraded` aunque los pods estén sanos
3. AWS Load Balancer Controller (con reinicio automático post-upgrade para el certificado del webhook)
4. ExternalDNS
5. cert-manager + un `ClusterIssuer` self-signed (no hay dominio público real para validar un challenge
   DNS-01 de Let's Encrypt contra la zona Route53 privada)
6. El namespace `sharedlbs` + el **ALB compartido** (`crud-eksshared-001`): genera un
   certificado wildcard self-signed vía cert-manager, lo importa/actualiza en ACM, y aplica el Ingress
   bootstrap (`k8s/sharedlbs/ingress.yaml.tpl`) con ese cert + el bucket de logs
7. Un segundo grupo de ALB **dedicado** (`crud-devops-pipeline-nginx-001`, solo HTTP, sin cert/logs) —
   demuestra el patrón alternativo del cluster de referencia (una app con su propio ALB, en vez de
   compartir el genérico)
8. Los `Application` de ArgoCD (`k8s/argocd/*.yaml`) — `crud-backend` y `nginx-test` se despliegan desde
   ahí, no por `kubectl apply` directo (GitOps puro, ver nota más abajo)

### 1.7 Verificar

```bash
kubectl get ingress --all-namespaces          # crud-backend-ingress y nginx-test-ingress deben tener ADDRESS
kubectl get applications -n argocd            # crud-backend y nginx-test deben quedar Synced
aws elbv2 describe-load-balancers --region us-east-1 --query "LoadBalancers[].{Name:LoadBalancerName,Scheme:Scheme}"  # deben aparecer 2 ALBs internal
```

Probar el circuito completo (DNS + tráfico real), desde la CloudShell:

```bash
curl http://crud-backend.internal.crud-devops-pipeline.local/healthz
curl http://nginx.internal.crud-devops-pipeline.local/
```

## 2. Destruir

**No lo hagas al revés de esto.** Los 2 ALBs, sus certificados en ACM, y los registros DNS los crean los
controllers (LBC/ExternalDNS/cert-manager) directamente en AWS, **no Terraform**. Si destruís el cluster
sin borrarlos primero: los ALBs quedan huérfanos en AWS (siguen facturando, invisibles para Terraform), y
el `terraform destroy` de `addons` puede fallar porque AWS no deja borrar una hosted zone de Route53 que
todavía tiene registros adentro.

### 2.1 Limpiar las apps (desde la CloudShell, con el cluster vivo)

**No borres los `Ingress` directamente** — los `Application` de ArgoCD tienen `selfHeal: true`, así que en
cuanto los borrás, ArgoCD ve que "falta" (sigue existiendo en git) y los vuelve a crear. Hay que borrar el
`Application` en sí, que tiene el finalizer `resources-finalizer.argocd.argoproj.io`: eso hace que ArgoCD
borre en cascada todo lo que gestiona (Ingress incluido) antes de terminar de borrarse a sí mismo.

```bash
kubectl delete application crud-backend -n argocd
kubectl delete application nginx-test -n argocd
```

Esto borra las reglas de cada app dentro de su grupo de ALB — pero **no borra el ALB en sí todavía**,
porque el Ingress bootstrap de cada grupo (en `sharedlbs`) sigue vivo. El LBC solo destruye el ALB físico
cuando el **último** Ingress de ese grupo desaparece.

### 2.2 Limpiar el andamiaje de los ALB compartidos

```bash
kubectl delete namespace sharedlbs
```

Esto borra los 2 Ingress bootstrap (`crud-eksshared-001` y `crud-devops-pipeline-nginx-001`)
y con ellos, los 2 ALBs reales en AWS. Como con los `delete` anteriores, puede tardar 1-3 min — es seguro
cortarlo con `Ctrl+C`, la limpieza del lado de AWS sigue corriendo igual. Confirmá que terminó:

```bash
aws elbv2 describe-load-balancers --region us-east-1 --query "LoadBalancers[].LoadBalancerName" --output text
# debe devolver vacío antes de seguir
```

(Opcional) El certificado importado a ACM no se borra solo — si querés limpiarlo:

```bash
aws acm list-certificates --region us-east-1 --query "CertificateSummaryList[?DomainName=='*.internal.crud-devops-pipeline.local'].CertificateArn" --output text
aws acm delete-certificate --region us-east-1 --certificate-arn <ARN>
```

### 2.3 Destruir la infraestructura (desde tu terminal local)

```bash
cd infra/environments/dev/addons && terraform destroy -auto-approve
cd ../eks && terraform destroy -auto-approve
cd ../tgw && terraform destroy -auto-approve
cd ../data && terraform destroy -auto-approve
cd ../networking && terraform destroy -auto-approve
```

### 2.4 Verificar que no quedó nada corriendo

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
- La instalación del AWS Load Balancer Controller vía Helm regenera su certificado TLS del webhook en
  cada `helm upgrade` sin reiniciar los pods necesariamente — `bootstrap.sh` ya incluye un
  `kubectl rollout restart` automático después de instalarlo/actualizarlo para evitar que esto rompa la
  creación de cualquier Service/Pod nuevo en el cluster.
- **Patrón de ALB compartido (IngressGroup):** ningún Ingress de app real (`k8s/base/ingress.yaml`,
  `k8s/pruebas-cni/ingress.yaml`) define su propio ALB — solo llevan `group.name`/`group.order` +
  `target-type`/`healthcheck-path` (config por target-group) + sus reglas de `host`/`path`. Todo lo que
  define el ALB en sí (`scheme`, `listen-ports`, `certificate-arn`, `ssl-policy`, `load-balancer-name`,
  `load-balancer-attributes`) vive **solo** en el Ingress bootstrap del grupo, en `sharedlbs`. Si agregás
  una app nueva: sumala al grupo compartido (mismo `group.name` que `crud-backend`) si puede compartir
  ALB, o armale su propio par bootstrap+grupo dedicado (como `nginx`/`crud-devops-pipeline-nginx-001`) si
  necesita configuración propia (certificado distinto, logs separados, etc.) — igual que hace el cluster
  de referencia con apps como mulesoft.
- **Las apps (`crud-backend`, `nginx-test`) se despliegan solo vía ArgoCD**, nunca con `kubectl apply`
  directo desde `bootstrap.sh` — ese script está acotado a infraestructura de cluster que se crea una sola
  vez (controllers + el andamiaje de `sharedlbs`), consistente con el principio de GitOps puro del proyecto.
- **Los nombres de ALB en AWS tienen un límite de 32 caracteres.** Si le ponés `load-balancer-name`
  explícito a un Ingress bootstrap (como el del grupo compartido) y se pasa de 32, el LBC nunca va a poder
  crear el balanceador — se queda con `FailedBuildModel: load balancer name cannot be longer than 32` para
  siempre, sin que el `kubectl apply` en sí falle (el Ingress se crea bien, solo que el LBC no logra
  aprovisionar nada). El grupo `nginx` no tiene este problema porque nunca le seteamos ese annotation
  (AWS le generó un nombre corto automáticamente).
- **Sin `metrics-server`, cualquier `HorizontalPodAutoscaler` se queda en `TARGETS: <unknown>`** y ArgoCD
  marca la `Application` entera como `Degraded`, aunque los pods estén sanos y la app responda tráfico
  real perfectamente. `bootstrap.sh` ya lo instala (con `--kubelet-insecure-tls`, necesario en EKS).
