---
title: "Building an AI Task Recommender Because I Was Tired of Choice Paralysis"
date: 2025-06-14T10:00:00+10:00
draft: false
description: "How I solved my morning productivity problem with Go, OpenAI, and some questionable architectural decisions"
tags: 
  - "AI"
  - "productivity"
  - "ADHD"
  - "golang"
  - "automation"
  - "task-management"
  - "openai"
  - "vikunja"
categories:
  - "Development"
  - "Personal Projects"
author: "Kirill"
slug: "ai-task-recommender-choice-paralysis"
keywords:
  - "ADHD productivity tools"
  - "AI task management"
  - "decision paralysis"
  - "cognitive load"
  - "personal automation"
  - "Go development"
toc: true
featured: true
series: ["Building Better Tools"]
---

## The Problem

Every morning I'd open Vikunja, stare at 20+ tasks, and spend way too long deciding what to work on. Classic ADHD decision paralysis - my brain would just freeze looking at all the options.

I timed it once: 28 minutes from opening my task list to actually starting work. That's ridiculous.

The core issue wasn't time management, it was **decision overhead**. I needed something to just tell me "work on this task right now" based on my current energy and available time.

## What I Built

A system that embeds cognitive metadata in task descriptions and uses AI to recommend the best task for my current state. The architecture flows from Claude through an MCP Server to OpenAI and finally to Vikunja.

Tasks get tagged with energy requirements and focus modes, capturing not just what needs to be done, but the cognitive state required to do it effectively.

When I ask "what should I work on?", it filters my tasks and returns 1-3 recommendations with reasoning.

## Architecture Decisions (And Why)

### Embedding Metadata in Descriptions

Instead of a separate database, I stuff JSON metadata directly into Vikunja task descriptions. A task might look like:

*Fix the deployment pipeline timeout issue*

*{energy: "high", mode: "deep", extend: true, minutes: 60}*

**Why this works:**
- No schema migrations or new infrastructure
- Metadata travels with the task if exported/moved
- Gradual adoption - untagged tasks still work fine
- Simple parsing with clear separation

**The downside:** It's a bit hacky and makes descriptions messier.

### Multi-Tier AI Architecture

I use different LLMs for different jobs:
- **Claude**: Natural language interface ("I have 30 minutes and medium energy")
- **OpenAI**: Task analysis and recommendation logic
- **MCP Protocol**: Structured communication between them

This felt over-engineered at first, but each model is genuinely better at its specific role. Claude excels at understanding context, OpenAI is solid at analytical reasoning.

### Go Client Implementation

Built a proper HTTP client for Vikunja with retry logic and structured logging. Nothing fancy, just reliable. The key was making it production-ready from day one since this is a tool I actually depend on.

## Implementation Details

### Metadata Extraction

The trickiest part was cleanly separating JSON from readable content. The system needs to extract structured metadata while preserving the human-readable task description.

### AI Integration

OpenAI integration is straightforward - build a prompt with task options and cognitive context. Temperature set to 0.3 for consistent recommendations. Higher values made it too random.

### MCP Server

The MCP server exposes four tools:
- `daily-focus`: Get multiple recommendations
- `get-focus-recommendation`: Single best task
- `get-task-metadata`: Extract metadata from existing tasks  
- `upsert_task`: Create/update with metadata

Standard Go HTTP server, nothing special. The MCP protocol handles the Claude integration.

## What Actually Works

**Energy matching:** Tasks tagged with "low" energy actually work better when I'm tired. Sounds obvious but the difference is noticeable.

**Mode differentiation:** "Deep" vs "quick" vs "admin" modes help a lot. Deep work in a quick-task mindset is frustrating.

**Time boundaries:** Respecting available session length prevents starting tasks I can't finish.

**AI reasoning:** Getting explanations like "matches your energy level and builds on yesterday's work" helps me trust the recommendations.

## What Doesn't Work (Yet)

**Learning from outcomes:** The system doesn't track whether recommendations were good. I started building this but haven't finished it.

**Context switching cost:** Doesn't account for the overhead of switching between different types of work.

**Interruption handling:** No support for "I got interrupted, what now?"

**Dependency awareness:** Doesn't understand task relationships or blocking issues.

## Performance and Reliability

- Task operations: <500ms
- AI recommendations: 2-3 seconds
- Error handling: Comprehensive retry logic
- Logging: Structured JSON for debugging

The Go implementation is solid. Haven't had any reliability issues in daily use.

## Lessons Learned

### Personal Tools Need Production Quality
Since I depend on this daily, half-broken functionality is worse than no functionality. Building it properly from the start was worth the extra time.

### Cognitive State Is Real Data
Treating energy levels and focus modes as first-class data types made the system much more useful than generic task filtering.

### AI Integration Is Easier Than Expected
The hardest part wasn't the AI calls, it was designing good prompts and handling edge cases in responses.

### Metadata Embedding Works
Shoving JSON in descriptions seemed hacky but turned out to be practical and robust.

## Results

Morning task selection: 28 minutes → 2 minutes.

That's 26 minutes of recovered time every day. The system isn't perfect but it solved the core problem: eliminating decision paralysis.

More importantly, I actually use it. A lot of personal productivity tools end up abandoned, but this one stuck because it addresses a real daily pain point.

## Architecture Overview

The full implementation lives at [github.com/BelKirill/vikunja-mcp](https://github.com/BelKirill/vikunja-mcp). 

The system includes comprehensive HTTP client handling, MCP server implementation, AI integration with prompt management, and structured data models for cognitive metadata.

The architecture is probably over-engineered for a personal tool, but it's been stable and extensible.

## Next Steps

I want to add outcome tracking - did I actually complete the recommended task? Was it the right choice? The data would help improve recommendations over time.

Also considering making this work for other people, but that requires solving the cold-start problem when you don't have any tagged tasks yet.

For now, it works for me, and that was the whole point.

---

*Building tools for your own daily frustrations turns out to be pretty rewarding. The feedback loop is immediate and the requirements are crystal clear.*