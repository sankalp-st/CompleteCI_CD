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

<p align="center">
  <img src="assets/AWS_setup.png" width="49%" alt="AWS console" />
  <img src="assets/EC2_Setup.png" width="49%" alt="Launching the EC2 instance" />
</p>
<p align="center">
  <img src="assets/connect_to_ec2.png" width="49%" alt="Connecting to EC2 via SSH" />
</p>

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

<p align="center">
  <img src="assets/install_jdk.png" width="49%" alt="Installing JDK on the EC2 server" />
  <img src="assets/ec2_jenkins.png" width="49%" alt="Unlocking Jenkins with the initial admin password" />
</p>
<p align="center">
  <img src="assets/install_jenkins_plugins.png" width="80%" alt="Installed Jenkins plugins" />
</p>

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

<p align="center">
  <img src="assets/install_docker_on_EC2_server.png" width="80%" alt="Installing Docker on the EC2 server" />
</p>

Under **Manage Jenkins → Credentials → System → Global Credentials**, add:

| Credential                  | Type               | ID            |
|------------------------------|--------------------|--------------|
| SonarQube token               | Secret text         | `sonar-token` |
| Docker Hub username/password  | Username & password | `docker-cred` |
| GitHub Personal Access Token  | Secret text         | `github`      |

<p align="center">
  <img src="assets/added_sonar_cofig_to_jenkins.png" width="49%" alt="SonarQube token added to Jenkins credentials" />
  <img src="assets/added_all_the_credentials_.png" width="49%" alt="All credentials configured in Jenkins" />
</p>

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

<p align="center">
  <img src="assets/Create_a_Pipeline_in_Jenkins.png" width="80%" alt="Creating a new Pipeline job in Jenkins" />
</p>
<p align="center">
  <img src="assets/after_10_attemps_ci_pipeline_was_done.png" width="80%" alt="CI pipeline stages passing" />
</p>

## 6. Install Argo CD & Deploy

Start a cluster (example uses Minikube):

```bash
minikube start --driver=hyperkit
```

<p align="center">
  <img src="assets/install_minikube.png" width="60%" alt="Installing Minikube" />
</p>

Install Argo CD:

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

<p align="center">
  <img src="assets/install_argoCD_in_local_k8s_cluster.png" width="49%" alt="Argo CD login screen" />
  <img src="assets/setup_argoCD.png" width="49%" alt="Creating an Argo CD application" />
</p>

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

<p align="center">
  <img src="assets/complete_argoCD_setup.png" width="80%" alt="Argo CD application synced and healthy" />
</p>

**Docker image pushed & running locally**

<p align="center">
  <img src="assets/docker_image_created_after_complete_cicd_.png" width="49%" alt="Docker image pushed to Docker Hub" />
  <img src="assets/DockerContainer_in_local.png" width="49%" alt="Container running locally in Docker Desktop" />
</p>
<p align="center">
  <img src="assets/run_app_through_docker_container.png" width="49%" alt="App running via Docker container" />
  <img src="assets/app_running_on_localhost.png" width="49%" alt="App running on localhost" />
</p>

**Final result — running end-to-end on the EC2/Kubernetes deployment**

<p align="center">
  <img src="assets/final_result_which_is_running_on_the_EC2_server_with_complete_CICD.png" width="80%" alt="Final application running after the complete CI/CD pipeline" />
</p>

---

## Tech Stack

- **CI**: Jenkins, Maven, SonarQube, Docker, Docker Hub
- **CD**: Argo CD (GitOps)
- **Runtime**: Kubernetes (Minikube for local dev)
- **App**: Java Spring Boot

## License

Add your license of choice here (e.g. MIT).
