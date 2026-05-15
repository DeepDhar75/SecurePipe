# 🛡️ SecurePipe v2.0 — End-to-End DevSecOps Pipeline

> A production-grade DevSecOps CI/CD pipeline integrating 5 security stages — Secrets Detection, SAST, Container Scanning, IaC Scanning, and DAST — enforcing shift-left security at every commit.

![Pipeline](https://img.shields.io/badge/Pipeline-GitHub_Actions-blue)
![Security](https://img.shields.io/badge/Security-Shift--Left-green)
![License](https://img.shields.io/badge/License-MIT-yellow)

---

## 🔄 Pipeline Architecture

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│  Trufflehog │───▶│    Build    │───▶│  SonarQube  │───▶│    Trivy    │───▶│   Checkov   │───▶│  OWASP ZAP  │
│  (Secrets)  │    │   Docker    │    │   (SAST)    │    │ (Container) │    │    (IaC)    │    │   (DAST)    │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
                                                                                                       │
                                                                                                       ▼
                                                                                               ┌─────────────┐
                                                                                               │   Deploy    │
                                                                                               │ (all pass)  │
                                                                                               └─────────────┘
```

| Stage | Tool | What it catches |
|-------|------|-----------------|
| 🔐 Secrets Detection | **Trufflehog** | Leaked API keys, tokens, credentials in code |
| 🔍 SAST | **SonarQube** | Code-level vulnerabilities, injection flaws, code smells |
| 🐳 Container Scan | **Trivy** | CVEs in base image & OS packages |
| 🏗️ IaC Scan | **Checkov** | Cloud misconfigurations in Terraform (CIS benchmarks) |
| 🌐 DAST | **OWASP ZAP** | Runtime vulnerabilities in the running application |

**Pipeline fails fast** — any CRITICAL/HIGH finding blocks deployment.

---

## 📁 Project Structure

```
SecurePipe/
├── .github/
│   └── workflows/
│       └── devsecops-pipeline.yml   # ← Main pipeline
├── .zap/
│   └── rules.tsv                    # OWASP ZAP rule overrides
├── app/
│   ├── app.py                       # Flask application
│   ├── requirements.txt
│   └── tests/
│       └── test_app.py              # Pytest tests (coverage for SonarQube)
├── terraform/
│   └── main.tf                      # Hardened AWS IaC (Checkov target)
├── docker-compose.yml               # Local dev + SonarQube
├── Dockerfile                       # Hardened multi-stage build
├── sonar-project.properties         # SonarQube config
└── README.md
```

---

## ⚙️ GitHub Secrets Required

Add these in **Settings → Secrets and variables → Actions**:

| Secret | Description |
|--------|-------------|
| `SONAR_TOKEN` | Token from SonarQube → My Account → Security |
| `SONAR_HOST_URL` | e.g. `https://sonarqube.yourdomain.com` or SonarCloud URL |

---

## 🚀 Local Setup

### 1. Clone & start local stack
```bash
git clone https://github.com/DeepDhar75/SecurePipe
cd SecurePipe

# Start app + SonarQube + PostgreSQL
docker compose up -d

# SonarQube UI → http://localhost:9000 (admin/admin)
# App          → http://localhost:5000
```

### 2. Run SonarQube scan locally
```bash
# Install sonar-scanner
brew install sonar-scanner   # macOS
# or download from https://docs.sonarqube.org/latest/analysis/scan/sonarscanner/

# Set token from SonarQube UI
export SONAR_TOKEN=your_token_here
export SONAR_HOST_URL=http://localhost:9000

sonar-scanner
```

### 3. Run Trivy locally
```bash
# Install Trivy
brew install aquasecurity/trivy/trivy

# Build and scan
docker build -t securepipe-app:local .
trivy image --severity CRITICAL,HIGH securepipe-app:local
```

### 4. Run Checkov locally
```bash
pip install checkov
checkov -d terraform/ --framework terraform
```

### 5. Run Trufflehog locally
```bash
pip install trufflehog3
trufflehog filesystem . --only-verified
```

### 6. Run OWASP ZAP locally
```bash
# Start app first
docker compose up app -d

# Run ZAP baseline scan
docker run -t ghcr.io/zaproxy/zaproxy:stable zap-baseline.py \
    -t http://localhost:5000 \
    -r zap-report.html
```

---

## 🔒 Container Security Controls

The Docker image enforces RHCSC-aligned hardening:

- ✅ Non-root user (`appuser:appgroup` — UID 1001)
- ✅ Read-only root filesystem
- ✅ All Linux capabilities dropped (`--cap-drop ALL`)
- ✅ `no-new-privileges` flag
- ✅ Pinned base image tags
- ✅ Multi-stage build (no build tools in final image)
- ✅ Gunicorn instead of Flask dev server
- ✅ Docker HEALTHCHECK configured

---

## 🏗️ IaC Security Controls (Terraform)

Checkov validates against CIS benchmarks:

- ✅ `CKV_AWS_8` — EC2 no public IP, EBS encrypted
- ✅ `CKV_AWS_19` — S3 encryption at rest
- ✅ `CKV_AWS_21` — S3 versioning enabled
- ✅ `CKV_AWS_57` — S3 public access blocked
- ✅ `CKV_AWS_126` — EC2 detailed monitoring
- ✅ `CKV_AWS_135` — IMDSv2 enforced
- ✅ Least-privilege IAM policies

---

## 📊 Security Reports

All scan reports are saved as GitHub Actions artifacts and uploaded to the Security tab (SARIF format):

- `trivy-results.sarif` → GitHub Security → Code scanning
- `checkov-results.sarif` → GitHub Security → Code scanning
- `zap-baseline-report` → GitHub Actions artifacts
- SonarQube dashboard → Quality Gate status

---

## 🎯 Why This Pipeline Matters

Traditional CI/CD: **Code → Build → Test → Deploy**

SecurePipe: **Code → [Secrets] → Build → [SAST] → [Container] → [IaC] → [DAST] → Deploy**

Every security gate is automated. No security engineer needs to manually review before deployment — the pipeline catches issues at the source.

---

## 🛠️ Tech Stack

`GitHub Actions` · `Docker` · `Flask` · `PostgreSQL` · `Trufflehog` · `SonarQube` · `Trivy` · `Checkov` · `OWASP ZAP` · `Terraform` · `AWS`

---

*Built by [Deep Dhar](https://linkedin.com/in/deep-dhar7b1700283) — DevSecOps Engineer*
