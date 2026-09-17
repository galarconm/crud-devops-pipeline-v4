apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: crud-backend-001
  namespace: sharedlbs
  annotations:
    alb.ingress.kubernetes.io/scheme: internal
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/group.name: crud-backend-001
    alb.ingress.kubernetes.io/group.order: "1"
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP":80},{"HTTPS":443}]'
    alb.ingress.kubernetes.io/certificate-arn: ${ACM_CERT_ARN}
    alb.ingress.kubernetes.io/ssl-policy: ELBSecurityPolicy-TLS13-1-2-2021-06
    alb.ingress.kubernetes.io/load-balancer-name: crud-backend-001
    alb.ingress.kubernetes.io/load-balancer-attributes: access_logs.s3.enabled=true,access_logs.s3.bucket=${ALB_LOGS_BUCKET},access_logs.s3.prefix=alb/crud-backend-001
spec:
  ingressClassName: alb
  rules:
    - host: bootstrap-alb.internal.crud-devops-pipeline.local
      http:
        paths:
          - path: /__bootstrap
            pathType: Prefix
            backend:
              service:
                name: dummy-service
                port:
                  number: 80
