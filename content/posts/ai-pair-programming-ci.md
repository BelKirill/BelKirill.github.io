+++
title = "Setting Up CI for a Personal Project with AI Pair Programming — A Beginner-Friendly Guide"
date = "2025-05-27"
draft = true
+++


> **TL;DR:** Continuous Integration (CI) is a friendly robot that automatically checks your code every time you hit **Save → Commit → Push**. When you’re coding with AI helpers like GitHub Copilot, that robot becomes your safety net. This post shows you—step by step—how to set up that robot for a small Go project.

---

## 1  What *Is* Continuous Integration, Exactly?

Think of building software like writing a group story: everyone adds sentences and paragraphs. If nobody proofs the story until the very end, you might discover plot holes or typos too late. **CI is the auto-proofreader** that runs every time someone adds new text, pointing out problems immediately.

Put differently, CI is a service (often free) that:
1. *Fetches* your latest code from GitHub.
2. *Runs checks*—formatters, linters, tests, builds.
3. *Reports* success or failure in a neat  / ❌ badge.

The sooner you know something broke, the cheaper it is to fix—this idea is called **“shift-left”**.

---

## 2  Why Does CI Matter More When You Use AI Helpers?

AI pair-programming is amazing: Copilot or ChatGPT can spit out functions in seconds. But speed can hide subtle issues—typos, inefficient loops, variables you never use. A basic CI pipeline:
- **Formats** code (so human + AI write in the same style).
- **Lints** for common mistakes.
- **Runs tests** so AI-suggested code doesn’t quietly break features.

Bottom line: CI lets you experiment with AI fearlessly—if the robot says ❌ you fix and move on.

---

## 3  The Tools We’ll Use (All Free)

| Purpose | Tool | Why You Need It |
|---------|------|-----------------|
| Format Go code | **gofmt** | Makes files consistent—no debates about spaces vs. tabs. |
| Organise imports | **goimports** | Adds missing imports, removes unused ones. |
| Catch bugs & style issues | **golangci-lint** | Bundles dozens of linters into one fast run. |
| Run checks *before* committing | **pre-commit** | Stops bad code at the door. |
| Run checks in the cloud | **GitHub Actions** | Free minutes for public & small private repos. |
| Build & ship the app | **Docker** | Optional for later deployment—nice to have. |

*You don’t need a fancy server or paid plan; GitHub gives generous free runners.*

---

## 4  Step-By-Step: Your First CI Pipeline

### 4.1  Set Up Local Guards with pre-commit
1. **Install** pre-commit:
   ```bash
   pip install pre-commit  # works on macOS/Linux/Windows (needs Python)
   ```
2. **Create** a file called `.pre-commit-config.yaml` in your project root:
   ```yaml
   repos:
     - repo: https://github.com/dnephin/pre-commit-golang
       rev: v0.4.0
       hooks:
         - id: go-fmt
         - id: go-imports
         - id: golangci-lint
   ```
3. **Activate** the hooks:
   ```bash
   pre-commit install
   ```
Now every `git commit` runs these checks automatically—no excuses!

### 4.2  Add Cloud Checks with GitHub Actions
Create `.github/workflows/ci.yml`:
```yaml
name: CI

on:
  push: {branches: [main]}
  pull_request: {}

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-go@v5
        with:
          go-version: '1.22'

      # Run pre-commit on all files
      - name: Lint & Format
        run: |
          pip install pre-commit
          go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
          pre-commit run --all-files

      # Run unit tests
      - name: Go test
        run: go test ./...
```
Push this to GitHub → the Actions tab shows a green ✔️ or red ❌ for each push.

*Tip:* If the AI writes the YAML for you, copy‑paste but still read it—you’re responsible, not the AI.

---

## 5  FAQ for Absolute Beginners

> **Do I need tests before using CI?**  
> Not at first! Start with format + lint; add tests when you’re ready.

> **Won’t CI slow me down?**  
> The opposite: catching issues early saves hours later. The cloud run happens in parallel—you keep coding.

> **What if I don’t know Docker?**  
> Skip it for now. You can add a Docker step once your project needs deployment.

---

## 6  Next Steps

1. **Invite your AI partner** to write a simple unit test file—then watch CI run it.
2. **Explore golangci-lint rules** (they’re configurable, so you decide how strict).
3. **Share your repo**—visitors will see green badges and trust your code.

---

### Final Thought

CI is like brushing your teeth: a small daily habit that prevents big pain later. Pair it with AI coding assistants and you get the best of both worlds—creative speed *and* solid quality. Once you master this workflow, you’ll wonder how you ever coded without it.

Happy (and safe) hacking! 🚀