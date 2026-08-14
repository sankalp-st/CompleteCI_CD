# GitOps CI/CD Pipeline — Jenkins + SonarQube + Docker + Argo CD + Kubernetes

An end-to-end GitOps CI/CD pipeline for a Java Spring Boot application. Continuous Integration (Jenkins) is fully decoupled from Continuous Delivery (Argo CD), with Git as the single source of truth for the desired cluster state.

> Based on the workflow demonstrated in Abhishek Veeramalla's "Jenkins Zero to Hero" GitOps tutorial.

---

## Architecture

```
 Developer            Jenkins (CI)                  GitHub (Manifests)        Argo CD (CD)          Kubernetes
 ─────────           ──────────────                 ──────────────────       ─────────────         ───────────
 git push  ───────▶  1. mvn clean package
                     2. SonarQube scan
                     3. Docker build & push
                     4. Update image tag  ────────▶  manifest repo updated
                        (sed in shell script)                                 detects change ─────▶ rolling update
                                                                               (auto-sync +
                                                                                self-heal)
```

**Flow summary**
1. Developers push application code to GitHub.
2. Jenkins builds the Spring Boot app with Maven, runs a SonarQube scan, builds a Docker image, pushes it to Docker Hub, and updates the image tag in the Kubernetes manifest repo.
3. Argo CD watches the manifest repo and automatically syncs any change to the Kubernetes cluster.

---

## Prerequisites

- AWS account (for EC2 host) — or any VM/host capable of running Jenkins + SonarQube
- A Kubernetes cluster (Minikube for local testing, or any managed cluster)
- Docker Hub account
- GitHub account with a Personal Access Token
- Forked copy of the application + manifest repositories

---

## 1. Provision Infrastructure

- Launch an AWS EC2 Ubuntu instance — **t2.large** (2 vCPU / 8 GB RAM) minimum, since Jenkins and SonarQube are memory-hungry.
- Open inbound security group rules for:
  - `8080` — Jenkins
  - `9000` — SonarQube
- SSH into the instance using your PEM key.

## 2. Install & Configure Jenkins

```bash
sudo apt update
sudo apt install openjdk-11-jdk -y
# Add the Jenkins apt keyring & repository, then:
sudo apt install jenkins -y
```

- Access Jenkins at `http://<EC2-Public-IP>:8080`
- Get the initial admin password:
  ```bash
  sudo cat /var/lib/jenkins/secrets/initialAdminPassword
  ```
- Complete the setup wizard, then install these plugins under **Manage Jenkins → Plugins → Available Plugins**:
  - `Docker Pipeline`
  - `SonarQube Scanner`

## 3. Set Up SonarQube

```bash
sudo adduser sonarqube
sudo su - sonarqube

wget https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-9.9.0.65466.zip
unzip sonarqube-*.zip

./sonarqube-*/bin/linux-x86-64/sonar.sh start
```

- Access SonarQube at `http://<EC2-Public-IP>:9000` (default login: `admin` / `admin`)
- Go to **My Account → Security** and generate an authentication token named `Jenkins`

## 4. Configure Jenkins Tools & Credentials

Install Docker on the host and let Jenkins use it:

```bash
sudo apt install docker.io -y
sudo usermod -aG docker jenkins
sudo systemctl restart docker
sudo systemctl restart jenkins
```

Under **Manage Jenkins → Credentials → System → Global Credentials**, add:

| Credential                  | Type               | ID            |
|------------------------------|--------------------|--------------|
| SonarQube token               | Secret text         | `sonar-token` |
| Docker Hub username/password  | Username & password | `docker-cred` |
| GitHub Personal Access Token  | Secret text         | `github`      |

## 5. Create the Pipeline

Fork the sample project repository (e.g. `AbhishekVeeramalla/Jenkins-Zero-To-Hero`).

The `Jenkinsfile` runs these stages:

1. **Build & Test** — `mvn clean package`
2. **SonarQube Scan** — `mvn sonar:sonar`
3. **Docker Build & Push** — containerizes the built `.jar` and pushes the image to Docker Hub
4. **Manifest Update** — uses `sed` in a shell step to bump the image tag in the Kubernetes deployment YAML

In Jenkins, create a **Pipeline** job:
- SCM: your forked GitHub repo URL
- Branch: `main`
- Script path: `spring-boot-app/Jenkinsfile`

## 6. Install Argo CD & Deploy

Start a cluster (example uses Minikube):

```bash
minikube start --driver=hyperkit
```

Install Argo CD:

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

Expose the Argo CD server (change the service to `NodePort`, or use `kubectl port-forward`).

Get the initial admin password:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

In the Argo CD UI:
1. Click **New App**
2. Repository URL → your manifests repo (e.g. `spring-boot-app-manifests`)
3. Cluster URL → `https://kubernetes.default.svc`
4. Namespace → `default`
5. Enable **Automated Sync** and **Self-Healing**

---

## Verification

- **CI**: Trigger the Jenkins pipeline manually or via a GitHub webhook. Confirm the SonarQube report at `http://<EC2-Public-IP>:9000`.
- **CD**: Once Jenkins commits the new image tag, Argo CD detects the change in the manifest repo and performs a rolling update on the Kubernetes deployment automatically.

---

## Tech Stack

- **CI**: Jenkins, Maven, SonarQube, Docker, Docker Hub
- **CD**: Argo CD (GitOps)
- **Runtime**: Kubernetes (Minikube for local dev)
- **App**: Java Spring Boot

## License

Add your license of choice here (e.g. MIT).
