---
title: "Zero-Trust Secrets for Infrastructure-as-Code with 1Password CLI"
date: 2026-03-19
draft: false
summary: "How op run keeps secrets out of AI agent context windows and bootstraps IaC workflows — and where cloud-native secret managers take over"
description: "How I use op run to keep secrets out of AI agent context windows and bootstrap IaC workflows — where it fits, where cloud-native secret managers take over, and the gaps you need to know about."
tags: ["devops", "security", "iac", "opentofu", "1password", "secrets", "ai", "claudeops"]
categories: ["DevOps", "Security"]
keywords: ["1password", "op run", "opentofu", "secrets management", "iac", "external secrets operator", "claude-ops", "zero-trust"]
author: "Gil Blinov"
slug: "zero-trust-secrets-iac-1password-cli"
series: "Claude-Ops"
reading_time: 8
toc: true
---

In my [last post]({{< ref "posts/2026-03-17-claude-ops-next-step-devops-evolution" >}}), I mentioned a pattern: `.env` files with `op://` references, wrapped with `op run`. I promised a deeper dive. Here it is.

This is how I manage secrets for OpenTofu in contexts where a cloud-native secret manager isn't available yet — bootstrapping new infrastructure, homelab setups, local development, and the messy pre-production phase where GCP Secret Manager or AWS Secrets Manager aren't in the picture. No Vault cluster, no SOPS keyrings, no plaintext on disk. Just 1Password doing what it already does well, extended to infrastructure.

**To be clear upfront:** for production workloads, cloud-native secret managers (GCP Secret Manager, AWS Secrets Manager) paired with External Secrets Operator are the right answer. I use them daily. This post is about everything that happens *before* that infrastructure exists.

---

## Why This Matters More in the Age of AI Agents

This pattern existed before AI coding agents, but AI agents made it urgent.

If you're using Claude Code, Cursor, Copilot, or any AI-assisted development tool for infrastructure work — and if you're not, you will be — you have a new threat model to think about. These agents operate inside your context window. They see your files, your terminal output, your environment. They're incredibly useful for proposing `kubectl` commands, writing Helm charts, debugging Crossplane compositions. I use Claude Code daily for exactly this kind of work.

But here's the problem: **an AI agent's context window is not a secure boundary.** Conversations can be logged, cached, used for debugging, or (depending on the tool) sent to external APIs. If your secrets are in plaintext files, environment variables, or shell history on the machine where your agent runs, they're one accidental `cat .env` or `env | grep` away from being in the context window.

The `op run` pattern solves this cleanly. The agent sees your `.env` file and reads this:

```bash
TF_VAR_db_password="op://Homelab/database/password"
```

That's a pointer. It's useless without your 1Password session. The agent can reason about the command shape, propose the right `op run` invocation, and understand what secrets are needed — all without ever seeing a credential.

When the command actually runs, `op run` resolves the references in a subprocess. The plaintext exists only in the child process environment for the duration of the command. It never enters the agent's context, never appears in your conversation log, never gets sent anywhere.

This is the principle I laid out in the Claude-Ops post: **Claude proposes the command shape. `op run` fills in the secrets at execution time. The context window stays clean.**

If you're doing any infrastructure work with AI agents and you're not using a pattern like this, you're trusting that every tool in your chain handles secrets correctly. I'd rather not trust that.

---

## The Problem With How Most Teams Handle IaC Secrets

You've seen the patterns. Maybe you're living one of them right now.

A `terraform.tfvars` in `.gitignore` with plaintext credentials. A SOPS-encrypted file that three people know how to decrypt. A `.env` file that someone copy-pasted from Slack six months ago. Environment variables exported in `.bashrc` that survive every shell session forever. A K3s token hardcoded in a bootstrap script on your homelab NUC.

They all share the same failure mode: **secrets exist as plaintext on disk**, in shell history, or in some file that's one bad `git add .` away from a breach. And in the bootstrap phase — before your cloud secret manager exists — these patterns are the default because nothing better is obvious.

---

## How `op run` Works

The 1Password CLI (`op`) has a command called `op run` that solves the disk-residency problem cleanly.

You create an `.env` file that contains **references**, not values:

```bash
# .env — safe to commit, safe to share, boring to leak
TF_VAR_gitlab_token="op://FirmusAI/GitLab - PAT with API scope/pat"
K3S_TOKEN="op://Homelab/k3s-cluster/token"
TF_VAR_cloudflare_api_token="op://Homelab/cloudflare/api-token"
```

Then you wrap your command:

```bash
op run --env-file=.env -- tofu plan
```

That's it. `op run` authenticates to 1Password, resolves every `op://` URI to its current value, spawns a subprocess with the real secrets injected as environment variables, and tears it all down when the process exits. It even intercepts stdout/stderr to replace any accidentally leaked secret values with `<concealed by 1Password>`.

The secrets never touch disk. They never enter your shell history. They exist only in the child process's environment for the duration of the command.

---

## Where This Fits (And Where It Doesn't)

Let me be direct about scope. `op run` is not my production secrets strategy. Here's where it lives in the stack.

### Production: Cloud-Native Secret Managers Win

For anything running in a cloud environment, **GCP Secret Manager or AWS Secrets Manager + External Secrets Operator is the right answer.** Native IAM integration, automatic rotation, audit logging, pay-as-you-go pricing, zero infrastructure to manage. ESO bridges the gap to Kubernetes beautifully — secrets sync from the cloud provider into K8s Secrets without anyone touching them.

I use this pattern daily at work. It's battle-tested, it scales, and it's what I'd recommend to any team with production cloud workloads.

### Bootstrap / Homelab / Local Dev: Where `op run` Shines

But there's a phase before all that exists. You're standing up a new cluster. You're bootstrapping Crossplane before it can manage itself. You're running `tofu apply` on your homelab K3s setup from your laptop. You're iterating on IaC modules locally before pushing to CI.

In these contexts, you don't have a cloud secret manager yet — or you're working outside a cloud provider entirely. That's where `op run` earns its keep.

### vs. the Other Bootstrap Options

**vs. SOPS**: SOPS is great — it's a CNCF Sandbox project now, well-maintained, zero cost. But it requires managing encryption keys (KMS, GPG, or age), a `.sops.yaml` config, and a decrypt-then-source pipeline before every run. Secret rotation means re-encrypting files and committing new ciphertext. With `op run`, rotation happens in 1Password. Every invocation gets the current value. No PRs to update ciphertext.

**vs. HashiCorp Vault**: Still overkill for bootstrap and homelab. You're managing clusters, unseal keys, storage backends, HA configs — all to solve a problem that a password manager already handles. OpenBao (the Linux Foundation fork) reduces the licensing friction but carries the same operational weight.

**vs. Infisical/Doppler**: Genuinely good newer options. Infisical especially — open source, 16K+ GitHub stars, growing fast. Worth evaluating if you're starting fresh. But if your team already uses 1Password, adding another tool for the bootstrap phase is overhead you probably don't need.

The advantage of `op run` for this niche is **zero additional infrastructure on top of something you're already paying for**. Once your cloud environment is up and your secret manager is running, `op run` steps aside and ESO takes over.

### The Homelab Plot Twist: 1Password as Your ESO Backend

Here's what makes 1Password particularly interesting for homelab setups: it doesn't just handle the bootstrap phase. **1Password can be the secret store backend for External Secrets Operator itself.**

The [1Password Connect server](https://developer.1password.com/docs/connect/) runs as two containers (connect-api + connect-sync) inside your cluster, and the [onepassword-connect ESO provider](https://external-secrets.io/latest/provider/1password-automation/) lets you define `ExternalSecret` resources that pull directly from your 1Password vaults — the same vaults you use for everything else.

```yaml
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: onepassword
spec:
  provider:
    onepassword:
      connectHost: http://onepassword-connect:8080
      vaults:
        homelab: 1
      auth:
        secretRef:
          connectTokenSecretRef:
            name: op-credentials
            key: 1password-credentials.json
---
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: cloudflare-api
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: onepassword
    kind: SecretStore
  target:
    name: cloudflare-credentials
  data:
    - secretKey: api-token
      remoteRef:
        key: cloudflare
        property: api-token
```

This is what drives my homelab. 1Password is the single source of truth for *everything* — `op run` for IaC bootstrap, Connect + ESO for runtime secrets in Kubernetes. No GCP Secret Manager, no AWS Secrets Manager, no Vault. Just the password manager I'm already paying for, doing double duty.

The workflow becomes: bootstrap the cluster with `op run`, deploy Connect server and ESO as part of the platform bootstrap, and from that point on every application gets its secrets through standard `ExternalSecret` resources. Same secret, same vault, two delivery mechanisms for two different phases.

---

## What `op run` Does NOT Protect Against

Here's where I have to be honest, because most blog posts about this pattern stop at the happy path.

### State File Leakage — The Big One

When `op run` sets `TF_VAR_db_password` and your OpenTofu config uses it like this:

```hcl
resource "aws_db_instance" "main" {
  password = var.db_password
}
```

The resolved plaintext value ends up in `terraform.tfstate`. It doesn't matter that the injection was clean. Terraform/OpenTofu needs to track resource attributes for drift detection, and `password` is an attribute. Your state file becomes an accidental secret store.

`sensitive = true` on the variable only redacts CLI output. The value is still in state, in plaintext, in whatever backend you're using.

**This is the biggest blind spot in the `op run` pattern, and most write-ups don't mention it.**

### Process Environment Exposure

Secrets live in the child process's environment. On Linux, anything that can read `/proc/<pid>/environ` as the same user sees them. Core dumps, crash reporters, and `TF_LOG=TRACE` will all happily print your secrets.

### Secret Inventory Disclosure

Your `.env` files aren't sensitive, but they reveal your vault structure — item names, field names, organizational patterns. An attacker who reads them knows exactly what to target.

### 1Password as a Single Point of Failure

If 1Password is down, you can't deploy. Unlike SOPS where encrypted files are local, `op run` requires network access at invocation time.

---

## Practical Setup: Getting Started in 10 Minutes

If you want to try this today:

**1. Install the CLI and authenticate:**

```bash
# macOS
brew install 1password-cli

# Verify
op --version  # Should be 2.32.x+

# Sign in (first time)
op account add --address my-team.1password.com
eval $(op signin)
```

**2. Create your `.env` file with references:**

```bash
# Find your secret's reference URI
op item list --vault Homelab
op item get "k3s-cluster" --fields token --format json

# Build your .env
cat > .env << 'EOF'
TF_VAR_cloudflare_api_token="op://Homelab/cloudflare/api-token"
TF_VAR_tailscale_auth_key="op://Homelab/tailscale/auth-key"
EOF
```

**3. Run your IaC:**

```bash
op run --env-file=.env -- tofu plan
op run --env-file=.env -- tofu apply
```

**4. Commit the `.env` file.** Yes, really. It contains pointers, not secrets. It's as sensitive as a Helm values file that references External Secrets.

---

## The Honest Take

`op run` is not a production secrets strategy for cloud workloads. Cloud-native secret managers with ESO are — and if you have them available, use them.

But for homelab and bootstrap contexts, 1Password plays a bigger role than most people realize. `op run` handles the pre-cluster phase where no secret manager exists yet. Once ESO is running, 1Password Connect becomes the secret store backend. Same vaults, same secrets, two delivery mechanisms. For cloud work, it's a bridge to GSM or ASM. For homelab, it's the entire secrets infrastructure — and that's a perfectly valid architecture when you're not operating at cloud scale.

The `.env` file is the bootstrap interface. Connect + ESO is the runtime interface. 1Password is the backend for both.

But there are real gaps — state file leakage being the biggest. The good news is that 2025-2026 brought real solutions: ephemeral resources, write-only arguments, and OpenTofu state encryption. That's the next post.

---

*This is the pattern I referenced in [Claude-Ops: The Next Step in the DevOps Evolution]({{< ref "posts/2026-03-17-claude-ops-next-step-devops-evolution" >}}). Next up: [Closing the Gaps — Ephemeral Resources, State Encryption, and the Full Secrets Stack]({{< ref "posts/2026-03-19-closing-the-gaps-iac-secrets" >}}).*
