%{ for az, subnet_id in az_subnets ~}
apiVersion: crd.k8s.amazonaws.com/v1alpha1
kind: ENIConfig
metadata:
  name: ${az}
spec:
  subnet: ${subnet_id}
  securityGroups:
    - ${node_sg_id}
---
%{ endfor ~}
