# Infrastructure Design

## Introduction

The attention dataset is built on top of two public datasets hosted in BigQuery:

* Wikipedia Pageviews
* Wikidata

Together they represent several terabytes of source data and are continuously updated.

While BigQuery solves the analytical processing problem, it does not solve the operational one.

The project still requires a way to:

* Execute transformations automatically
* Deploy infrastructure consistently
* Monitor execution
* Publish documentation
* Deploy analytical applications
* Manage credentials securely
* Reproduce the entire platform on another account

The objective was therefore not simply to build a data pipeline.

The objective was to build a reproducible analytics platform.

---

# Design Principles

The infrastructure was designed around five principles.

## 1. Reproducibility

A user should be able to recreate the platform without manually provisioning cloud resources.

The entire environment is defined through Infrastructure as Code and GitHub Actions workflows.

After bootstrap, deployment requires only:

* An AWS account
* A GCP service account
* Two required GitHub secrets

The reporting layer can additionally be deployed automatically by providing an optional Power BI credential.

Everything else is provisioned automatically.

---

## 2. Low Operational Cost

Most of the computation occurs inside BigQuery.

The orchestration layer therefore does not need permanent infrastructure.

Compute resources should exist only while transformations are running.

This requirement drove the selection of AWS Fargate as the execution environment.

A typical pipeline execution costs approximately:

**$0.05 per run**

Interestingly, AWS Secrets Manager costs more than the compute layer itself.

---

## 3. Reliability

The platform is designed to execute unattended.

Every execution follows the same lifecycle:

1. Retrieve credentials
2. Execute transformations
3. Collect metadata
4. Publish telemetry
5. Refresh the dashboard via api
6. Terminate resources

No manual intervention is required during normal operation.

---

## 4. Security

Long-lived cloud credentials were intentionally avoided.

Authentication between GitHub and AWS is performed through OpenID Connect (OIDC).

As a result:

* No AWS access keys are stored in GitHub.
* Credentials are generated dynamically.
* Permissions are controlled through IAM roles.

External service credentials (GCP and optionally Power BI) remain encrypted inside GitHub Secrets and are injected only during workflow execution.

---

## 5. Observability

The pipeline should explain not only what happened but also how much it cost.

Operational telemetry was therefore treated as a first-class requirement rather than an afterthought.

---

# Architecture Overview

The platform combines AWS and GCP.

BigQuery performs analytical processing.

AWS provides orchestration, scheduling, monitoring, deployment, and secret management.

GitHub Actions provides continuous integration and continuous delivery.

When Power BI credentials are available, the reporting layer is deployed automatically as part of the delivery pipeline.

The architecture can be divided into five layers:

* Bootstrap
* Infrastructure Provisioning
* Execution
* Observability
* Analytical Application Deployment

---

# Bootstrap Infrastructure

Before the platform can deploy itself, a minimal bootstrap layer must be created.

This solves a circular dependency problem.

Terraform requires permissions to provision infrastructure.

However, the IAM role used by Terraform must itself already exist.

Rather than asking users to manually configure AWS resources, the repository includes a dedicated `bootstrap/` infrastructure module.

The only manual steps are:

1. Authenticate locally with an AWS account.
2. Navigate to the bootstrap directory.
3. Execute the provided Terraform configuration.

The bootstrap module automatically provisions:

* Terraform state storage
* GitHub OIDC trust configuration
* Deployment IAM role

Once completed, Terraform outputs:

```text
AWS_GITHUB_ROLE_ARN
```

This value is added as a GitHub Secret and becomes the deployment identity used by GitHub Actions.
Bootstrap is the only manual infrastructure step required by the project.

---

# Reproducible Deployment

After bootstrap, reproducing the platform requires only a minimal set of credentials.

### Required

```text
AWS_GITHUB_ROLE_ARN
GCP_SERVICE_ACCOUNT_KEY
```

The GCP service account requires:

* BigQuery User
* BigQuery Job User
* BigQuery Data Editor
* Resource Viewer

These permissions allow the platform to:

* Create and update tables
* Execute BigQuery jobs
* Run dbt models
* Query INFORMATION_SCHEMA for telemetry

### Optional

```text
POWER_BI_CREDENTIALS
```

Power BI deployment is entirely optional.

When this secret is omitted, the analytical warehouse is deployed normally and remains fully operational.

Providing the credential enables automatic deployment of the reporting layer.

The secret contains a JSON document with the following structure:

```json
{
  "TENANT_ID": "...",
  "CLIENT_ID": "...",
  "CLIENT_SECRET": "...",
  "FABRIC_EMAIL": "mail@example.com",
  "WORKSPACE_NAME": "New Wikipedia Analysis Workspace",
  "DATASET_NAME": "wikipedia dashboard"
}
```
---

# Infrastructure as Code

Infrastructure is managed through Terraform.

Terraform provisions:

* ECS Fargate
* ECR
* EventBridge
* CloudWatch
* SNS
* Secrets Manager

The infrastructure definition becomes the source of truth.

Rather than documenting infrastructure manually, the platform documents itself through code.

---

# Why Fargate?

Several execution environments were considered.

EC2 was rejected because it requires managing virtual machines that remain active even when idle.

Lambda was rejected because dbt execution is long-running and container-oriented.

Fargate offered a simpler model.

The platform launches a container only when required.

After execution completes, the container disappears.

Because BigQuery performs nearly all computational work, the container functions primarily as an orchestrator.

This results in extremely low execution costs while preserving operational simplicity.

---

# Continuous Integration and Deployment

The deployment pipeline is implemented through GitHub Actions.

Rather than executing every workflow for every change, the pipeline uses path-based change detection.

Examples:

* Infrastructure changes trigger Terraform validation.
* dbt changes trigger dbt validation.
* Telemetry changes trigger Python unit tests.
* Dashboard changes trigger Power BI deployment.
* Documentation changes avoid unnecessary execution.

This significantly reduces execution time while maintaining validation coverage.

---

## Infrastructure Deployment

Infrastructure deployments require approval through a protected GitHub environment.

Once approved:

1. GitHub authenticates using OIDC.
2. Terraform initializes state.
3. Terraform generates a plan.
4. Terraform applies changes.

The deployed environment is automatically reconciled with repository definitions.

---

## Data Validation

Changes affecting the transformation layer trigger:

* dbt debug
* dbt seed
* dbt run
* dbt test

This ensures analytical models remain valid before deployment.

---

## Container Delivery

Successful validation produces a new container image.

The image is:

1. Built by GitHub Actions.
2. Published to ECR.
3. Pulled automatically during the next scheduled execution.

The execution environment therefore remains synchronized with repository state.

---

## Documentation Publishing

dbt documentation is generated automatically after successful validation.

The generated lineage graph and model documentation are published through GitHub Pages.

Documentation therefore evolves alongside the project rather than becoming stale.

---

## Dashboard Deployment

The reporting layer follows the same continuous delivery model as the analytical platform.

When the optional `POWER_BI_CREDENTIALS` secret is available, changes affecting either the Power BI deployment package or the dashboard automatically trigger deployment.

The workflow:

1. Uploads the PBIX report.
2. Creates the Power BI workspace if necessary.
3. Grants administrator access to the configured Fabric user.
4. Detects the automatically provisioned BigQuery datasource.
5. Configures datasource credentials using the supplied Google service account.
6. Updates Power Query deployment parameters.
7. Triggers the initial dataset refresh.

As a result, no manual configuration is required after importing the report.

The reporting layer becomes fully reproducible and version-controlled alongside the analytical platform.

---

# Execution Layer

Execution is intentionally simple.

An EventBridge schedule launches a Fargate task.

The task:

1. Retrieves the GCP service account from AWS Secrets Manager.
2. Creates a temporary credentials file.
3. Executes dbt transformations.
4. Executes telemetry collection.
5. Publishes operational metrics.
6. Terminates.

No persistent compute resources remain active after execution.

---

# Cross-Cloud Design

The project intentionally combines AWS and GCP.

This was primarily driven by data locality.

Wikipedia Pageviews and Wikidata are both available as public BigQuery datasets.

Moving several terabytes of source data into AWS would introduce unnecessary complexity and cost.

Instead:

* BigQuery performs analytical processing.
* AWS orchestrates execution.

This keeps computation close to the data while leveraging AWS services for operational management.

---

# Observability

One of the project's goals was understanding not only what the pipeline produced but also what it consumed.

After each execution, telemetry is extracted directly from BigQuery's INFORMATION_SCHEMA tables.

This includes:

* Query duration
* Bytes billed
* Query status
* Error information
* Executed SQL

The telemetry layer enriches this information using dbt metadata embedded in generated queries.

This makes it possible to attribute cost and runtime directly to individual dbt assets.

---

## CloudWatch Metrics

The telemetry pipeline publishes metrics such as:

* GB scanned
* Query duration
* Query count
* Failed queries
* Run duration
* Run success rate

These metrics are stored in CloudWatch and visualized through operational dashboards.

The result is a lightweight observability layer capable of tracking both platform health and analytical cost.

---

# Results

The final platform provides:

* Fully automated execution
* Infrastructure as Code
* Secure cloud authentication
* Continuous deployment
* Automated documentation
* Optional Power BI deployment
* Automated workspace provisioning
* Automated semantic model configuration
* Automated datasource binding
* Automated report parameterization
* Cost attribution by dbt asset
* Cloud-native observability
* Cross-cloud orchestration

while maintaining a very small operational footprint.

The resulting system transforms a collection of scripts into a reproducible analytics platform capable of processing multi-terabyte public datasets while optionally delivering a fully configured Power BI analytical application.
