# policies/security.rego
package main
 
# ── Política 1: Ningún contenedor puede correr como root ─────────────────
# Si un contenedor comprometeado corre como root tiene acceso total al nodo
deny[msg] {
  input.kind == "Deployment"
  container := input.spec.template.spec.containers[_]
  not container.securityContext.runAsNonRoot
  msg := sprintf(
    "POLICY FAIL: Container '%v' must set securityContext.runAsNonRoot: true",
    [container.name]
  )
}
 
# ── Política 2: Todo Deployment debe tener readinessProbe ────────────────
# Sin readinessProbe el Service envía tráfico a pods que no están listos
deny[msg] {
  input.kind == "Deployment"
  container := input.spec.template.spec.containers[_]
  not container.readinessProbe
  msg := sprintf(
    "POLICY FAIL: Container '%v' must define a readinessProbe",
    [container.name]
  )
}
 
# ── Política 3: Las imágenes deben venir del ECR privado ─────────────────
# Evita que alguien use una imagen de DockerHub con malware
deny[msg] {
  input.kind == "Deployment"
  container := input.spec.template.spec.containers[_]
  not startswith(container.image, "654654193269.dkr.ecr")
  msg := sprintf(
    "POLICY FAIL: Container '%v' uses image '%v' — only ECR images are allowed",
    [container.name, container.image]
  )
}
 
# ── Política 4: Todo contenedor debe tener resource requests ─────────────
# Sin requests el HPA no puede calcular CPU y el scheduler no puede planificar
deny[msg] {
  input.kind == "Deployment"
  container := input.spec.template.spec.containers[_]
  not container.resources.requests
  msg := sprintf(
    "POLICY FAIL: Container '%v' must define resources.requests",
    [container.name]
  )
}