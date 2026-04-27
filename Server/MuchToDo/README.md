# MuchToDo API — Container Assessment

A containerized deployment of the MuchToDo RESTful API built with Go, MongoDB, and Redis. This project demonstrates Docker and Kubernetes deployment using Kind for local development.

## Project Structure

\`\`\`
much-to-do/Server/MuchToDo/
├── cmd/                        # Application entry point
├── internal/                   # Application source code
├── docs/                       # Swagger documentation
├── Dockerfile                  # Optimized Docker image
├── docker-compose.yaml         # Local development setup
├── .dockerignore               # Docker build exclusions
├── .env.example                # Environment variable template
├── kubernetes/
│   ├── namespace.yaml
│   ├── mongodb/
│   │   ├── mongodb-secret.yaml
│   │   ├── mongodb-configmap.yaml
│   │   ├── mongodb-pvc.yaml
│   │   ├── mongodb-deployment.yaml
│   │   └── mongodb-service.yaml
│   ├── backend/
│   │   ├── backend-secret.yaml
│   │   ├── backend-configmap.yaml
│   │   ├── backend-deployment.yaml
│   │   └── backend-service.yaml
│   └── ingress.yaml
├── scripts/
│   ├── docker-build.sh
│   ├── docker-run.sh
│   ├── k8s-deploy.sh
│   └── k8s-cleanup.sh
└── README.md
\`\`\`

## Prerequisites

- Docker and Docker Compose
- Go 1.25+
- Kind (Kubernetes in Docker)
- kubectl
- openssl

---

## Phase 1: Docker Setup

### 1. Clone the Repository

\`\`\`bash
git clone https://github.com/YOUR_USERNAME/much-to-do.git
cd much-to-do/Server/MuchToDo
git checkout feature/backend-only
\`\`\`

### 2. Generate MongoDB Keyfile

\`\`\`bash
openssl rand -base64 756 > mongodb.key
sudo chown 999:999 mongodb.key
chmod 400 mongodb.key
\`\`\`

### 3. Configure Environment Variables

\`\`\`bash
cp .env.example .env
\`\`\`

Update .env with your values:

\`\`\`env
PORT=8080
MONGO_URI=mongodb://root:example@mongodb:27017/much_todo_db?authSource=admin&replicaSet=rs0
DB_NAME=much_todo_db
JWT_SECRET_KEY=your-super-secret-key
JWT_EXPIRATION_HOURS=72
ENABLE_CACHE=false
REDIS_ADDR=redis:6379
REDIS_PASSWORD=
LOG_LEVEL=DEBUG
LOG_FORMAT=json
\`\`\`

### 4. Build the Binary

\`\`\`bash
export PATH=\$PATH:/usr/local/go/bin:~/go/bin
swag init -g cmd/api/main.go
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -p 1 -ldflags="-w -s" -o muchtodo ./cmd/api/main.go
\`\`\`

### 5. Run with Docker Compose

\`\`\`bash
docker compose up --build
\`\`\`

### 6. Verify

\`\`\`bash
docker compose ps
curl http://localhost:8080/health
curl http://localhost:8080/
\`\`\`

Expected responses:
\`\`\`json
{"cache":"disabled","database":"ok"}
{"message":"Welcome to MuchToDo API"}
\`\`\`

### Docker Services

| Service | Port | Description |
|---|---|---|
| Backend API | 8080 | MuchToDo Go API |
| MongoDB | 27017 | Database (replica set) |
| Mongo Express | 8081 | MongoDB web UI |
| Redis | 6379 | Cache |
| Redis Commander | 8082 | Redis web UI |

---

## Phase 2: Kubernetes Deployment

### 1. Install Tools

\`\`\`bash
# kubectl
curl -LO "https://dl.k8s.io/release/\$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Kind
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.27.0/kind-linux-amd64
chmod +x ./kind && sudo mv ./kind /usr/local/bin/kind
\`\`\`

### 2. Create Kind Cluster

\`\`\`bash
kind create cluster --config kind-cluster.yaml
kubectl cluster-info --context kind-muchtodo-cluster
\`\`\`

### 3. Deploy to Kubernetes

\`\`\`bash
./scripts/k8s-deploy.sh
\`\`\`

Or manually:

\`\`\`bash
kind load docker-image muchtodo-backend:latest --name muchtodo-cluster
kind load docker-image mongo:8.0 --name muchtodo-cluster
kubectl apply -f kubernetes/namespace.yaml
kubectl apply -f kubernetes/mongodb/
kubectl apply -f kubernetes/backend/ --validate=false
kubectl apply -f kubernetes/ingress.yaml
\`\`\`

### 4. Initialise MongoDB Replica Set

\`\`\`bash
MONGO_POD=\$(kubectl get pod -n muchtodo -l app=mongodb -o jsonpath='{.items[0].metadata.name}')
kubectl exec -it \$MONGO_POD -n muchtodo -- mongosh -u root -p example \
  --authenticationDatabase admin \
  --eval "rs.initiate({_id:'rs0',members:[{_id:0,host:'mongodb-service:27017'}]})"
\`\`\`

### 5. Verify Kubernetes Deployment

\`\`\`bash
kubectl get pods -n muchtodo
kubectl get services -n muchtodo
kubectl get ingress -n muchtodo
curl http://localhost:30080/health
curl http://localhost:30080/
\`\`\`

### Kubernetes Resources

| Resource | Description |
|---|---|
| Namespace | muchtodo |
| MongoDB Deployment | 1 replica with PVC storage |
| MongoDB Service | ClusterIP on port 27017 |
| Backend Deployment | 2 replicas with health checks |
| Backend Service | NodePort on port 30080 |
| Ingress | Routes muchtodo.local to backend |
| PVC | 1Gi persistent storage for MongoDB |

---

## Cleanup

\`\`\`bash
# Docker
docker compose down -v

# Kubernetes
./scripts/k8s-cleanup.sh
\`\`\`

---

## API Endpoints

| Method | Endpoint | Description |
|---|---|---|
| GET | /health | Health check |
| GET | / | Welcome message |
| POST | /api/v1/users/register | Register user |
| POST | /api/v1/users/login | Login user |
| GET | /api/v1/todos | List todos |
| POST | /api/v1/todos | Create todo |
| PUT | /api/v1/todos/:id | Update todo |
| DELETE | /api/v1/todos/:id | Delete todo |
| GET | /swagger/index.html | Swagger UI |

---

## Troubleshooting

**MongoDB keyfile error:**
\`\`\`bash
openssl rand -base64 756 > mongodb.key
sudo chown 999:999 mongodb.key && chmod 400 mongodb.key
\`\`\`

**DNS issues in VM:**
\`\`\`bash
sudo bash -c 'echo "nameserver 8.8.8.8
nameserver 8.8.4.4" > /etc/resolv.conf'
sudo chattr +i /etc/resolv.conf
\`\`\`

**Out of memory during Go build:**
\`\`\`bash
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile && sudo mkswap /swapfile && sudo swapon /swapfile
\`\`\`

**MongoDB replica set not initiating:**
\`\`\`bash
MONGO_POD=\$(kubectl get pod -n muchtodo -l app=mongodb -o jsonpath='{.items[0].metadata.name}')
kubectl exec -it \$MONGO_POD -n muchtodo -- mongosh -u root -p example \
  --authenticationDatabase admin \
  --eval "rs.reconfig({_id:'rs0',members:[{_id:0,host:'mongodb-service:27017'}]}, {force:true})"
\`\`\`
