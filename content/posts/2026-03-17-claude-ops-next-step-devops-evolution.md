---
title: "Claude-Ops: The Next Step in the DevOps Evolution"
date: 2026-03-17
draft: false
summary: "From Click-Ops to Claude-Ops — how AI coding assistants fit into the infrastructure management evolution"
description: "An exploration of how Claude Code fits into the DevOps evolution as an interactive infrastructure partner for the messy pre-GitOps bootstrapping phase, with rules for safe operation."
tags: ["devops", "ai", "claudeops", "gitops", "automation"]
categories: ["DevOps", "AI"]
keywords: ["claude-ops", "devops evolution", "gitops", "claude code", "infrastructure automation", "bootstrapping"]
author: "Gil Blinov"
slug: "claude-ops-next-step-devops-evolution"
series: "Claude-Ops"
reading_time: 7
toc: true
---

# Claude-Ops: The Next Step in the DevOps Evolution

There's a pattern in how we've managed infrastructure over the years. Each era felt like progress — and it was — until the next one made the previous look primitive.

**Click-Ops → Ticket-Ops → GitOps → Claude-Ops**

Let me explain where I think we are, and where I think we're going.

---

## The Evolution

**Click-Ops** was clicking around in AWS consoles, Proxmox UIs, and GCP dashboards. Fast to start, impossible to reproduce, and a disaster for auditing. We've all been there.

**Ticket-Ops** was the "enterprise" answer: a human approval gate in front of every change. Slow, bureaucratic, and just Click-Ops with extra steps and a paper trail.

**GitOps** was the real leap. Infrastructure as code, pull requests as change control, ArgoCD doing the actual work. Reproducible, auditable, reviewable. This is where production systems should live.

But there's a gap GitOps doesn't cover: **the bootstrapping phase**. Before ArgoCD exists, before your cluster is up, before secrets are seeded — someone has to run commands. That someone used to be you, following a runbook, copy-pasting commands, making typos at 2am.

That's where Claude-Ops comes in.

---

## What Is Claude-Ops?

Claude-Ops is using an AI coding assistant — specifically Claude Code — to execute infrastructure operations interactively, as a pair-programming partner that also happens to be better at CLI than most humans.

I've stopped writing bootstrap scripts. Instead, I run **runbooks with Claude Code** to handle the messy pre-GitOps phase: provisioning nodes, joining clusters, seeding initial secrets, configuring CNI. Claude handles the CLI mechanics. I handle the decisions and the review.

The workflow looks like this:

1. I describe the objective and the current state
2. Claude proposes commands
3. **I review every command before it runs** — this is non-negotiable
4. Claude executes, observes the output, and adapts
5. GitOps takes over once the foundation is stable

---

## Why Claude Code Is Genuinely Better at CLI Than You

I'm not bad at CLI. But Claude Code has some structural advantages I can't compete with:

- It doesn't fat-finger flags
- It doesn't forget to escape a string
- It reads `man` pages by instinct
- It remembers the exact syntax for `jq`, `openssl`, `kubectl`, and `iptables` simultaneously
- It doesn't get tired at step 47 of a 60-step runbook

The honest truth: when I'm bootstrapping a K3s node at 11pm, I don't want to be the one typing `update-initramfs -u -k all`. I want to review that Claude typed it correctly.

---

## The Zero-Trust Secrets Rule

This is the most important operational principle in Claude-Ops: **Claude should never see your secrets in plaintext.**

My pattern: `.env` files with `op://` references, wrapped with `op run`.
```bash
# .env file (safe to read, boring to leak)
K3S_TOKEN=op://homelab/k3s-token/password
MASTER_IP=op://homelab/k3s-master/ip

# The actual invocation
op run --env-file .env -- curl -sfL https://get.k3s.io | sh -s - agent \
  --server https://${MASTER_IP}:6443
```

Claude proposes the command shape and the `.env` structure. `op run` resolves the secrets at execution time in your shell. Claude's context never contains a credential — it contains a pointer to one.

This matters because:
- Claude's context window is not your secrets vault
- A leaked conversation log shouldn't be a credential breach
- The `.env` file itself is auditable and reviewable without being dangerous

I'm writing a separate post on the full pattern.

---

## The Inertia Problem

Here's the failure mode I've had to actively guard against: **yes by inertia**.

Claude is fast and confident. Commands stream in, output looks clean, and it's very easy to keep hitting approve without really reading. Then you realize you've just done something irreversible.

`rm` has no undo. Cluster joins can be messy to unroll. A misconfigured CNI can leave you locked out.

My rules for Claude-Ops sessions:

- **Commit early and often.** After every meaningful change, document the state. If something breaks, you want a known-good checkpoint.
- **Pause before destructive operations.** Any command with `rm`, `kubectl delete`, `qm destroy`, or `--force` gets an extra second of thought, regardless of how obvious it looks.
- **Never approve in bulk.** If Claude proposes 5 commands at once, I review them one at a time. Batch approval is how mistakes happen.
- **Read the output.** Claude reads it too, but you need to have seen it yourself. Errors that look like warnings have burned me before.

---

## What This Is Good For

Claude-Ops shines in the pre-GitOps bootstrapping layer:

- Joining worker nodes to an existing cluster
- GPU passthrough configuration (IOMMU, VFIO, modprobe)
- CNI migration (Flannel → Cilium cleanup)
- Initial secret seeding before External Secrets Operator is up
- Recovery operations after an incident

It is **not** a replacement for GitOps for steady-state infrastructure. Once your cluster is up and ArgoCD is running, changes go through Git. Claude-Ops is for the work that happens before that.

---

## The Honest Take

The DevOps profession has always been about **leverage** — doing more with less manual intervention while maintaining control and auditability. Claude-Ops is the next increment of that. Not a revolution, an evolution.

You get:
- Faster than Click-Ops
- More information than Ticket-Ops
- Better control than either
- A partner that knows the CLI cold

What you give up:
- Nothing, if you review your commands
- Your production database, if you don't

The tool is genuinely good. The discipline around using it is still entirely on you.

---

*Next post: Zero-trust secrets injection for Claude Code using the 1Password CLI.*
