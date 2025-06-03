---
title: "Rolling My Own: When Learning Trumps Efficiency in API Client Development"
date: 2025-06-03
draft: false
description: "How I chose the harder path of building a custom Vikunja API client in Go instead of trimming an auto-generated one - and why scope delivery sometimes means taking the scenic route."
tags: ["go", "api-client", "devops", "learning", "vikunja", "software-development", "python-to-go"]
categories: ["Development", "Learning"]
keywords: ["Go API client", "Vikunja integration", "DevOps engineering", "learning Go", "custom API client", "software development roadblocks"]
author: "Your Name"
slug: "rolling-my-own-vikunja-api-client-go"
---

# Rolling My Own: When Learning Trumps Efficiency in API Client Development

Eight years in DevOps teaches you one thing above all else: there's always more than one way to solve a problem. But choosing which path to take? That's where experience meets psychology, and sometimes the "inefficient" choice is exactly what you need.

## The Roadblock: When Auto-Generation Goes Too Far

I hit a wall recently while working on a Vikunja integration project. The auto-generated OpenAPI client was... robust. Too robust. We're talking 111 files of generated Go code for what I needed to accomplish. Coming from Python, where I'd typically reach for `requests` and call it a day, this felt like bringing a freight train to deliver a letter.

The irony wasn't lost on me. Here I was, someone who's spent nearly a decade in the DevOps trenches, project managing everything from infrastructure migrations to CI/CD pipeline overhauls, and I was getting tripped up by an over-engineered API client.

## Two Paths Diverged in a Code Repository

I had two clear options ahead of me:

**Option 1: The Pragmatic Approach**
Trim the original `openapi.json` down to just what I needed. Auto-generate something more manageable—maybe 20-30 files instead of 111. Review the generated code, learn from it, then build a thin client wrapper with proper auth, retries, and error handling.

**Option 2: The Learning Path**
Roll my own API client from scratch.

In a work environment, the choice would be obvious. Option 1, every time. Ship fast, iterate, move on to the next sprint. If this were a time-critical project deliverable, I'd probably have switched back to Python entirely—leveraging my existing expertise to hit deadlines.

## When Engineering Meets Psychology

But here's where I did something different. I asked Claude (my current AI assistant) to think not just as a world-class DevOps engineer, but as a world-class psychologist as well—one inspired by Jung's approach to behavioral change and learning.

The response was illuminating: *It's completely normal to feel stalled when faced with such an overwhelming amount of generated material. Since you're learning Go and coming from Python, you would actually benefit more from rolling your own API client for Vikunja.*

This wasn't just technical advice—it was recognition that learning and rewiring your brain requires a different approach than simply getting things done.

## Choosing Scope Over Speed

For this project, I've decided that scope is the priority, and it will be delivered at all costs. But "at all costs" doesn't always mean "as fast as possible." Sometimes it means taking the path that builds the foundation for everything that comes after.

Rolling my own client means:
- Understanding every line of code that talks to the Vikunja API
- Learning Go idioms and patterns organically, not through generated abstractions
- Building exactly what I need, when I need it
- Creating something I can debug, extend, and maintain with confidence

## The DevOps Mindset Applied to Learning

My years in DevOps have taught me that the best solutions are often the ones you understand completely. When production breaks at 3 AM, you don't want to be debugging someone else's abstraction—you want to know exactly how your system works.

The same principle applies to learning a new language. Sure, I could lean on generated code and probably ship something faster. But six months from now, when I need to extend this client or debug a subtle API integration issue, which version of me will be better equipped to handle it?

## Ship Early, Learn Always

Don't get me wrong—I still believe in shipping early and often. But "shipping" doesn't always mean delivering to production. Sometimes it means delivering knowledge to your future self.

This project is my playground for learning Go properly. Every function I write, every error I handle, every retry mechanism I implement is building my Go intuition in a way that reading generated code never could.

In my project management days, I learned that the fastest way to complete a project isn't always the shortest path through it. Sometimes you need to slow down to speed up, take the scenic route to build the muscle memory that will make you faster in the long run.

## The Verdict

Am I taking the harder path? Absolutely. Will it take longer? Probably. But will I emerge from this project with a deeper understanding of Go, API design, and my own problem-solving capabilities? Without question.

Sometimes the best engineering decision isn't the most efficient one—it's the one that leaves you better equipped for the next challenge. And in a field that evolves as rapidly as ours does, that kind of learning investment always pays dividends.

So here I am, rolling my own Vikunja client, one carefully crafted function at a time. And this *is* the DevOps way—specifically embodying The Third Way from The Phoenix Project: continuous learning and experimentation. Sometimes the most DevOps thing you can do is choose the path that builds your capabilities for the long run.