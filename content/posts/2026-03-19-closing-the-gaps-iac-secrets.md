---
title: "Closing the Gaps: Ephemeral Resources, State Encryption, and the Full IaC Secrets Stack"
date: 2026-03-19
draft: false
summary: "Ephemeral resources, write-only arguments, OpenTofu state encryption, and CI/CD patterns — the modern mitigations that close the gaps in IaC secrets management"
description: "The modern solutions for IaC state file leakage: ephemeral resources in Terraform 1.10+ and OpenTofu 1.11+, write-only arguments, OpenTofu state encryption, and CI/CD patterns with 1Password service accounts and OIDC."
tags: ["devops", "security", "iac", "opentofu", "terraform", "1password", "secrets", "claudeops"]
categories: ["DevOps", "Security"]
keywords: ["ephemeral resources", "opentofu state encryption", "write-only arguments", "terraform 1.11", "iac secrets", "cicd secrets", "oidc"]
author: "Gil Blinov"
slug: "closing-the-gaps-iac-secrets"
series: "Claude-Ops"
reading_time: 8
toc: true
---

In the [previous post]({{< ref "posts/zero-trust-secrets-iac-1password-cli" >}}), I covered how `op run` keeps secrets off disk and out of AI agent context windows during IaC bootstrap. I also listed the gaps — state file leakage, process environment exposure, secret inventory disclosure, and 1Password as a single point of failure.

State file leakage is the big one. This post is about closing it, and about the full layered defense I'm running in 2026.

---

## The State File Problem, Restated

When `op run` sets `TF_VAR_db_password` and your OpenTofu config uses it like this:

```hcl
resource "aws_db_instance" "main" {
  password = var.db_password
}
```

The resolved plaintext value ends up in `terraform.tfstate`. It doesn't matter that the injection was clean. Terraform/OpenTofu needs to track resource attributes for drift detection, and `password` is an attribute. Your state file becomes an accidental secret store.

`sensitive = true` on the variable only redacts CLI output. The value is still in state, in plaintext, in whatever backend you're using.

**This is the biggest blind spot in the `op run` pattern, and most write-ups don't mention it.**

---

## Ephemeral Resources (Terraform 1.10+ / OpenTofu 1.11+)

This is the single biggest improvement in the IaC secrets landscape, and it applies whether you're in production or bootstrapping a homelab. Ephemeral resources are temporary — they're **never persisted in state or plan files**.

The 1Password Terraform provider (v3.2+) now supports them:

```hcl
ephemeral "onepassword_item" "db_creds" {
  vault = "Infrastructure"
  title = "database-prod"
}

resource "aws_db_instance" "main" {
  password_wo = ephemeral.onepassword_item.db_creds.password
}
```

The `password_wo` argument (write-only, Terraform 1.11+) accepts the value, sends it to the API, and **never stores it in state**. Combined with ephemeral resources, secrets flow through the system without leaving a trace.

This is the real solution to state file leakage — not marking variables as sensitive, not encrypting state after the fact. Just never writing the secret to state in the first place.

---

## OpenTofu State Encryption

If you're on OpenTofu (and for IaC work, I think you should be), you get client-side state encryption that Terraform still doesn't have. State and plan files are encrypted before they hit any backend.

For cloud setups, use KMS. For homelab where you don't have a cloud KMS, PBKDF2 with a passphrase works:

```hcl
# Homelab: passphrase-based encryption (no cloud KMS needed)
terraform {
  encryption {
    key_provider "pbkdf2" "state_key" {
      passphrase = var.state_passphrase  # or inject via op run
    }
    method "aes_gcm" "encrypt" {
      keys = key_provider.pbkdf2.state_key
    }
    state {
      method   = method.aes_gcm.encrypt
      enforced = true
    }
  }
}
```

```hcl
# Cloud: AWS KMS-backed encryption
terraform {
  encryption {
    key_provider "aws_kms" "state_key" {
      kms_key_id = "arn:aws:kms:us-east-1:123456789:key/abc-123"
      region     = "us-east-1"
      key_spec   = "AES_256"
    }
    method "aes_gcm" "encrypt" {
      keys = key_provider.aws_kms.state_key
    }
    state {
      method   = method.aes_gcm.encrypt
      enforced = true
    }
  }
}
```

The `enforced = true` flag prevents anyone from accidentally disabling encryption. This has been GA since OpenTofu 1.7. PBKDF2 works anywhere with just a passphrase (inject it via `op run`); KMS-backed encryption is better when you have cloud infrastructure available.

This doesn't prevent secrets from being in state — it ensures that if someone gets your state file, they get encrypted gibberish without the KMS key.

---

## The CI/CD Pattern (For Homelab and Personal Projects)

For production CI, your cloud provider's secret manager should be the source. But for homelab automation and personal projects running in GitHub Actions, 1Password service accounts keep things simple.

I combine OIDC (for AWS auth) with 1Password service accounts (for application secrets):

```yaml
jobs:
  deploy:
    runs-on: ubuntu-latest
    permissions:
      id-token: write
      contents: read
    steps:
      - uses: actions/checkout@v4

      # AWS auth via OIDC — no static credentials
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::123456789:role/github-tf
          aws-region: us-east-1

      # Application secrets via 1Password
      - uses: 1password/load-secrets-action@v3
        with:
          export-env: true
        env:
          OP_SERVICE_ACCOUNT_TOKEN: ${{ secrets.OP_SERVICE_ACCOUNT_TOKEN }}
          TF_VAR_db_password: op://Homelab/database/password
          TF_VAR_cloudflare_api_token: op://Homelab/cloudflare/api-token

      - run: |
          tofu init
          tofu apply -auto-approve -input=false
```

One static secret in the entire pipeline: the `OP_SERVICE_ACCOUNT_TOKEN`. Everything else is either OIDC-federated or resolved at runtime from 1Password.

Create separate service accounts per environment. Scope each to minimum required vaults. Vault access is immutable after creation — changing scope means creating a new service account.

One limitation worth knowing: 1Password doesn't support OIDC federation with GitHub Actions yet. The service account token is still a static credential you store as a GitHub secret. It's the one turtle at the bottom of the stack.

---

## The Full Stack

My secrets strategy in 2026 has two modes:

**Production (cloud workloads):**
1. **GCP Secret Manager / AWS Secrets Manager** as the source of truth
2. **External Secrets Operator** syncing secrets into Kubernetes
3. **Ephemeral resources + write-only arguments** for any IaC that touches secrets
4. **OpenTofu state encryption** as defense-in-depth
5. **OIDC everywhere** — no static cloud credentials in CI

**Bootstrap / homelab / local dev:**
1. **`op run`** for IaC and pre-cluster work — zero plaintext on disk, single source of truth
2. **1Password Connect + ESO** for runtime secrets once the cluster is up
3. **Ephemeral resources + write-only arguments** when the provider supports them
4. **OpenTofu state encryption** (PBKDF2 works without a cloud KMS)
5. **`sensitive = true`** on all secret variables and outputs to prevent log leakage

---

## The Honest Take

The IaC secrets landscape got meaningfully better in 2025-2026. Ephemeral resources and write-only arguments solve the state file problem at the source. OpenTofu state encryption adds defense-in-depth. OIDC eliminates static cloud credentials in CI.

None of these are magic. You still need to think about your threat model, understand what each layer does and doesn't protect, and choose the right tool for each phase — bootstrap, runtime, and CI. But the tools are finally good enough that "plaintext in `.tfvars`" is a choice, not a necessity.

The `op run` pattern from the previous post handles the bootstrap phase. Ephemeral resources handle the state file gap. Cloud-native secret managers handle production. Together, they cover the full lifecycle without a single secret on disk.

---

*This concludes the secrets arc of the [Claude-Ops series]({{< ref "posts/claude-ops-next-step-devops-evolution" >}}). The pattern: Claude proposes the command shape, `op run` fills in the secrets, ephemeral resources keep them out of state, and ESO handles runtime. Each layer does one thing well.*
