# CRUD DevOps Pipeline v4 — EKS + GitOps + Observability

Plataforma completa de CI/CD para una aplicación CRUD desplegada en AWS EKS, con infraestructura como código, despliegue continuo vía GitOps, y observabilidad completa. Construido como proyecto de portfolio para demostrar competencias reales de Cloud/DevOps Engineer.

## Arquitectura

```
┌─────────────┐     ┌──────────────┐     ┌─────────────┐
│   GitHub    │────▶│   GitHub     │────▶│  AWS ECR    │
│   (código)  │     │   Actions    │     │  (imágenes) │
└─────────────┘     └──────────────┘     └─────────────┘
                            │
                            ▼
                    ┌──────────────┐
                    │  Terraform   │
                    │ (VPC, EKS,   │
                    │  RDS, IAM)   │
                    └──────────────┘
                            │
                            ▼
                    ┌──────────────┐      ┌──────────────┐
                    │   AWS EKS    │◀────▶│   ArgoCD     │
                    │   Cluster    │      │  (GitOps)    │
                    └──────────────┘      └──────────────┘
                            │
              ┌─────────────┼─────────────┐
              ▼             ▼             ▼
        ┌──────────┐  ┌──────────┐  ┌──────────┐
        │  Backend │  │   ALB    │  │Prometheus│
        │   (API)  │  │ Ingress  │  │ Grafana  │
        └──────────┘  └──────────┘  └──────────┘
```

## Stack tecnológico

| Capa | Tecnología |
|---|---|
| Infraestructura | Terraform (módulos, backend remoto S3 + locking) |
| Orquestación | AWS EKS (Kubernetes) |
| GitOps | ArgoCD |
| CI/CD | GitHub Actions (5 pipelines) |
| Networking | AWS ALB Ingress Controller |
| Base de datos | AWS RDS (PostgreSQL), Secrets Manager |
| Seguridad | IRSA, Trivy (scanning de imágenes), OPA/Conftest (policy as code), Checkov |
| Observabilidad | Prometheus, Grafana, Alertmanager |
| Backend | Node.js / Express |

## Pipelines de CI/CD

| Pipeline | Trigger | Qué hace |
|---|---|---|
| `terraform.yml` | Push a `infra/**` | Aplica infraestructura (networking → data → eks → addons) |
| `ci.yml` | Push a `apps/**`, `k8s/**` | Lint, tests, security scan (Checkov), validación de manifiestos (kubeconform, Conftest) |
| `deploy.yml` | Push a `apps/**` | Build de imagen, scan de vulnerabilidades (Trivy), push a ECR, actualiza el tag en `k8s/base/deployment.yaml` |
| `bootstrap.yml` | Manual (`workflow_dispatch`) | Instala ArgoCD y el AWS Load Balancer Controller en un cluster nuevo, aplica las ArgoCD Applications iniciales |
| `platform.yml` | Push a `helm/**`, `k8s/monitoring/**` | Instala/actualiza el stack de Prometheus vía Helm, aplica reglas y ServiceMonitors |
| `teardown.yml` | Manual | Elimina ArgoCD Applications, desinstala Prometheus y el LBC (limpia el ALB) |
| `teardown-infra.yml` | Manual | Destruye toda la infraestructura de Terraform en orden inverso |

### Por qué bootstrap y teardown son manuales

El bootstrap de un cluster (instalar ArgoCD, el Load Balancer Controller, y las primeras Applications) es un evento que ocurre **una sola vez por cluster**, no en cada cambio de infraestructura. Encadenarlo automáticamente a `terraform.yml` causaría que se intentara reinstalar sobre un cluster que ya tiene todo funcionando cada vez que se aplique un cambio menor de Terraform. Por eso se dispara explícitamente con `workflow_dispatch`, justo después de que el cluster nace.

## Cómo levantar el proyecto desde cero

```bash
# 1. Infraestructura (automático con push, o manual)
# Push a infra/** dispara terraform.yml — espera ~20 min (EKS tarda)

# 2. Bootstrap del cluster (manual, una sola vez)
# GitHub → Actions → "Bootstrap - ArgoCD and Load Balancer Controller" → Run workflow

# 3. Verificar
aws eks update-kubeconfig --name crud-devops-pipeline-dev --region us-east-1
kubectl get applications -n argocd
kubectl get pods -n dev

# 4. Monitoring (automático si tocas helm/** o k8s/monitoring/**)
# O fuerza el trigger con un commit vacío en esos paths

# 5. Probar el healthcheck
ALB=$(kubectl get ingress crud-backend-ingress -n dev -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
curl http://$ALB/healthz
```

## Cómo destruir todo (para evitar costos)

```bash
# 1. Limpiar capa de Kubernetes (elimina el ALB)
# GitHub → Actions → "Teardown - ArgoCD and Load Balancer Controller" → Run workflow

# 2. Verificar que el ALB se eliminó
aws elbv2 describe-load-balancers --region us-east-1 \
  --query 'LoadBalancers[*].[LoadBalancerName,State.Code]' --output table

# 3. Destruir infraestructura
# GitHub → Actions → "Teardown - Destroy Infrastructure" → Run workflow
```

## Decisiones de diseño relevantes

- **Backend remoto de Terraform en S3** con locking nativo (`use_lockfile`), sin DynamoDB.
- **IRSA** (IAM Roles for Service Accounts) para que los pods accedan a AWS sin credenciales estáticas.
- **Trivy con `.trivyignore` documentado** — cada CVE suprimido incluye justificación y referencia a si está parcheado upstream.
- **Checkov en modo `soft_fail`** durante desarrollo activo, pensado para pasar a `hard_fail` una vez el código esté completamente hardenizado.
- **GitOps puro**: ningún `kubectl apply` manual de los manifiestos de la aplicación — todo pasa por ArgoCD sincronizando desde Git.
- **Separación de pipelines por ciclo de vida**: provisioning (Terraform) ≠ bootstrap (una vez) ≠ deploy continuo (cada cambio de código).

## Mejoras futuras

- [ ] Configurar `AlertmanagerConfig` con notificaciones reales a Slack (pendiente en `k8s/monitoring/pending/`)
- [ ] RDS: habilitar `manage_master_user_password` y `deletion_protection`
- [ ] Pipeline de Terraform: usar `terraform plan -out=tfplan` + `apply tfplan` para garantizar que el plan revisado es el que se ejecuta
- [ ] GitHub Environments con aprobación manual antes de los `apply` en producción
- [ ] Habilitar logging del control plane de EKS
- [ ] Cambiar Checkov de `soft_fail` a `hard_fail`

## Autor

Gary Alarcón — [LinkedIn] · [Portfolio]