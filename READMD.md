# 🧩 DevOps Assignment – Full Implementation Guide

## 1. Infrastructure Setup (Terraform)
This setup provisions complete AWS EKS infrastructure using Terraform.

### Network Architecture
**VPC:** 10.0.0.0/16 (65,536 IPs)

**Public Subnets:** 10.0.0.0/24, 10.0.1.0/24 (Internet Gateway access)  
**Private Subnets:** 10.0.10.0/24, 10.0.11.0/24 (NAT Gateway access)  
**NAT Gateways:** 2 (one per AZ)  
**Security Groups:** For EKS control plane and node access

```
VPC: 10.0.0.0/16
├── Public Subnets (Internet-facing)
│   ├── ap-south-1a: 10.0.0.0/24
│   └── ap-south-1b: 10.0.1.0/24
│       ├── Hosts: NAT Gateways, Internet Gateway
│       └── Route: 0.0.0.0/0 → Internet Gateway
│
└── Private Subnets (Isolated)
    ├── ap-south-1a: 10.0.10.0/24
    └── ap-south-1b: 10.0.11.0/24
        ├── Hosts: EKS Worker Nodes, Application Pods
        └── Route: 0.0.0.0/0 → NAT Gateway
```

### EKS Cluster
- **Control Plane:** Managed Kubernetes API
- **Worker Nodes:** 4 × t3.medium
- **Auto Scaling:** 2–5 nodes based on workload
- **Multi-AZ:** High availability (ap-south-1a, ap-south-1b)

Run:
```bash
cd terraform
terraform init
terraform apply
```

---

## 2. Docker Configuration
### Dockerfile Updates
```dockerfile
FROM python:3.13-slim

WORKDIR /src

RUN pip install uv

COPY ./requirements.txt /src/requirements.txt
RUN uv pip install --system -r requirements.txt

COPY . /src/

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

### requirements.txt
```
fastapi==0.119.0
httpx==0.28.1
pytest==8.3.5
pytest-cov==5.0.0
pytest-xdist==3.6.1
requests==2.32.4
uvicorn==0.33.0
uv==0.8.22
```

**Changes Made:**
- Base Image: `python:3.13-slim` (light, ARM-ready)
- Added `uv` package manager
- Fixed CMD for FastAPI startup
- Locked dependency versions

Build & Push:
```bash
docker build -t <ECR_REPO>/fastapi-app:latest .
docker push <ECR_REPO>/fastapi-app:latest
```

---

## 3. CI/CD (GitHub Actions)

### CI – `.github/workflows/ci.yml`
Trigger: Pull Request → `main` or `dev`

Steps:
1. Checkout code  
2. Setup Python 3.13  
3. Install dependencies  
4. Run unit tests (`make unittest`)  
5. Build Docker image with Git SHA tag  
6. Test image locally  

Purpose: Validate before merge

---

### CD – `.github/workflows/cd.yml`
Trigger: Push to `main` or `dev`

**Phase 1 – Build & Push**
- AWS auth using GitHub Secrets  
- Login to ECR  
- Build and push image with Git SHA tag  

**Phase 2 – Deploy**
- Configure `kubectl` for EKS access  
- Create namespace if missing  
- Deploy via Helm with updated tag  
- Verify rollout status  

**Phase 3 – Rollback**
- Auto rollback on deployment failure  
- Helm reverts to last working version  

**Secrets Used:**
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `ECR_REGISTRY`
- `EKS_CLUSTER`

---

## 4. Horizontal Pod Autoscaler (HPA)

### Configuration
```yaml
minReplicas: 2
maxReplicas: 10
metrics:
- type: Resource
  resource:
    name: cpu
    target:
      type: Utilization
      averageUtilization: 80
- type: Resource
  resource:
    name: memory
    target:
      type: Utilization
      averageUtilization: 80
```

**How It Works:**
- Collects CPU/Memory metrics via Metrics Server  
- Scales up if utilization > 80%  
- Scales down when load drops (cooldown 5 min)  
- Uses probes for health:
  - Liveness probe restarts unhealthy pods  
  - Readiness probe ensures only ready pods get traffic  

**Resources:**
- Requests: 100m CPU / 128Mi Memory  
- Limits: 200m CPU / 256Mi Memory  

---

## 5. Helm Charts & Deployment

### Structure
```
ecoligo-app/
├── Chart.yaml
├── values.yaml
└── templates/
    ├── deployment.yaml
    ├── service.yaml
    ├── hpa.yaml
    └── ingress.yaml
```

Deploy:
```bash
helm upgrade --install ecoligo-app helm/ecoligo-app   --namespace ecoligo-production   --set image.tag=<git-sha>
```

**Rollout Verification:**
```bash
kubectl rollout status deployment/fastapi-app -n ecoligo-production
```

**Rollback:**
```bash
helm rollback ecoligo-app 1 --namespace ecoligo-production
```

---

## 6. Ingress Controller Setup

Install NGINX Ingress Controller:
```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/cloud/deploy.yaml
```

### Ingress Configuration
kubectl apply -f https://github.com/jetstack/cert-manager/releases/download/v1.7.1/cert-manager.yaml
cluster-issuer.yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your-email@gmail.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
      - http01:
          ingress:
            class: nginx
kubectl apply -f cluster-issuer.yaml

`ingress-ecoligo.yaml`
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ecoligo-ingress
  namespace: ecoligo-production
  annotations:
    kubernetes.io/ingress.class: "nginx"
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
spec:
  ingressClassName: nginx
  tls:
    - hosts:
        - ecoligo.mvenkat.in
      secretName: ecoligo-tls
  rules:
    - host: ecoligo.mvenkat.in
      http:
        paths:
          - pathType: Prefix
            path: "/"
            backend:
              service:
                name: ecoligo-app
                port:
                  number: 8000
```

**Purpose:**  
Routes external traffic to the application service using TLS via Let’s Encrypt.

---

## 7. Metrics Server Setup
Install metrics-server to enable HPA:
```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

Verify:
```bash
kubectl get deployment metrics-server -n kube-system
```

---

## 8. Cluster Autoscaler

Apply config:
```bash
kubectl apply -f cluster-autoscaler-autodiscover.yaml
```

### Key Details
- Image: `registry.k8s.io/autoscaling/cluster-autoscaler:v1.32.1`
- Region: `ap-south-1`
- Discovery Mode: `asg:tag=k8s.io/cluster-autoscaler/enabled,k8s.io/cluster-autoscaler/ecoligo-production`

### How It Works
- Monitors unschedulable pods.
- If pods cannot be placed → adds EC2 nodes.  
- When idle → scales down nodes automatically.  
- **Node limits:** min = 2, max = 5 (defined in Terraform).

Check status:
```bash
kubectl -n kube-system get pods | grep cluster-autoscaler
```

---

## 9. Access Application
After deployment:
```bash
kubectl get ingress -n ecoligo-production
```
Access via:
```
https://ecoligo.mvenkat.in




```

---

## 10. Clean Up
```bash
terraform destroy
```

---

✅ **Current Status**
- Infrastructure: Live on AWS EKS  
- App: Running and reachable via Ingress  
- Scaling: Verified via HPA + Autoscaler  
- Monitoring: Metrics server enabled  
- CI/CD: Fully automated GitHub Actions pipeline

