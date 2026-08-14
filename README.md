# Demo Spring Boot app for GitOps CI/CD tutorial

This repository contains a minimal Spring Boot application and the supporting files you need to follow the CI/CD GitOps pipeline in the tutorial.

Files added:
- spring-boot-app: Maven project and source code
- spring-boot-app/Dockerfile: builds the runtime image
- spring-boot-app/Jenkinsfile: example pipeline (build, sonar, docker push, update manifest)
- spring-boot-app/scripts/update-manifest.sh: script used by Jenkins to update the deployment manifest
- spring-boot-app-manifests: Kubernetes manifests (Deployment + Service)

Required manual changes before using in CI:
- Edit `spring-boot-app/Jenkinsfile` and replace `<SONAR_HOST>` with your SonarQube host (e.g., the EC2 public IP).
- Replace `your-dockerhub-username` with your Docker Hub username in the Dockerfile, manifests and Jenkinsfile.
- Update `scripts/update-manifest.sh` push URL (`<your-org>/<your-repo>`) to your repository.

Quick local run:

```bash
mvn -f spring-boot-app clean package
java -jar spring-boot-app/target/demo-0.0.1-SNAPSHOT.jar
```

To build image locally:

```bash
docker build -t your-dockerhub-username/demo-app:local -f spring-boot-app/Dockerfile spring-boot-app
```
