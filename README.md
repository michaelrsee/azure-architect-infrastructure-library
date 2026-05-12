# Azure Architect Infrastructure Library

A modular Azure Bicep library aligned with the **AZ-305** (Designing Microsoft Azure Infrastructure Solutions) and **AZ-400** (Designing and Implementing Microsoft DevOps Solutions) certification objectives.

## Purpose

Each module in this library represents a reusable, exam-relevant Azure pattern. Modules are designed to be composable, parameterized for multiple environments, and deployable independently or as part of a larger solution.

## Modules

| Module | Pattern | AZ-305 Domain |
|---|---|---|
| [hub-spoke-vnet](hub-spoke-vnet/README.md) | Hub-spoke virtual network topology with bidirectional VNet peering | Design network connectivity solutions |
| [aks-cluster](aks-cluster/README.md) | AKS cluster with AAD RBAC, OIDC issuer, workload identity, and Container Insights | Design compute solutions using containers |
| [event-hub](event-hub/README.md) | Event Hubs namespace with multi-hub, per-hub consumer groups, and diagnostic settings | Design a messaging solution |

## Repository Structure

```
azure-architect-infrastructure-library/
├── hub-spoke-vnet/
│   ├── main.bicep                # Module entrypoint
│   ├── README.md                 # Module documentation and design notes
│   └── parameters/
│       └── dev.bicepparam        # Dev environment parameter file
├── aks-cluster/
│   ├── main.bicep
│   ├── README.md
│   └── parameters/
│       └── dev.bicepparam
├── event-hub/
│   ├── main.bicep
│   ├── README.md
│   └── parameters/
│       └── dev.bicepparam
├── tests/
│   └── unit/                     # Unit tests for individual modules
└── README.md
```

## Module Conventions

| File | Purpose |
|---|---|
| `main.bicep` | Declares all resources, parameters, and outputs |
| `README.md` | Describes the module, parameters, outputs, and cert alignment |
| `parameters/dev.bicepparam` | Concrete dev values using Bicep's `.bicepparam` format |

## Prerequisites

- [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli) >= 2.50
- [Bicep CLI](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/install) >= 0.24
- An Azure subscription with Contributor access for deployments

## Deploying a Module

```bash
# Validate
az deployment group validate \
  --resource-group <rg-name> \
  --template-file <module>/main.bicep \
  --parameters <module>/parameters/dev.bicepparam

# Deploy
az deployment group create \
  --resource-group <rg-name> \
  --template-file <module>/main.bicep \
  --parameters <module>/parameters/dev.bicepparam
```

## Running Tests

```bash
cd tests/unit
# Tests are run with Pester (PowerShell) or az bicep build for lint validation
```

## Cert Alignment

| Exam | Domain |
|---|---|
| AZ-305 | Design identity, governance, compute, storage, networking, and monitoring solutions |
| AZ-400 | Implement IaC, CI/CD pipelines, security, and compliance patterns |

## License

MIT — see [LICENSE](LICENSE).
