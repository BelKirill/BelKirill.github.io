---
title: "Building Intelligent Task Filters with OpenAI: From Natural Language to SQL-like Queries"
date: 2025-06-17T19:30:00+03:00
draft: false
description: "How I built an AI-powered natural language interface for my personal task management system using OpenAI GPT-4 and Go"
slug: "ai-powered-task-filtering-openai-go"
tags: 
  - "go"
  - "openai"
  - "ai"
  - "task-management"
  - "productivity"
  - "natural-language-processing"
  - "vikunja"
  - "adhd"
  - "personal-projects"
categories:
  - "Software Development"
  - "AI Integration"
  - "Productivity Tools"
keywords:
  - "OpenAI GPT-4"
  - "Go programming"
  - "task filtering"
  - "natural language processing"
  - "AI-powered tools"
  - "productivity systems"
  - "ADHD optimization"
  - "personal automation"
author: "Gil Blinov"
series: "ADHD-Optimized Productivity"
toc: true
featured: true
---

# Building Intelligent Task Filters with OpenAI: From Natural Language to SQL-like Queries

*How I built an AI-powered natural language interface for my personal task management system*

---

## The Problem: Filter Complexity vs. User Experience

Task management systems face a fundamental UX challenge: powerful filtering requires complex syntax that intimidates users. Traditional approaches force users to choose between:

- **Simple filters**: Easy to use but limited functionality
- **Advanced filters**: Powerful but require learning query syntax

In building my personal ADHD-optimized task management system, I discovered a third path: **AI-powered natural language filtering** that combines the best of both worlds.

## Architecture Overview

My solution uses OpenAI's GPT-4 to translate natural language requests into executable filter expressions for Vikunja, an open-source task management platform.

```
User Input: "urgent tasks due this week"
     ↓
OpenAI Translation Layer
     ↓
Filter Expression: 'labels = "urgent" && due_date >= now/w && due_date <= now/w+1w'
     ↓
Vikunja API Execution
```

## Implementation Deep Dive

### 1. The Translation Engine

My `OpenAIDecisionEngine` serves as the intelligent middleware between user intent and database queries:

```go
func (e *OpenAIDecisionEngine) SuggestFilter(ctx context.Context, request string) (*models.FilterSuggestionResponse, error) {
    log.Info("OpenAI: Suggesting a filter expression", "request", request)

    prompt := e.buildFilterSuggestionPrompt(request)
    
    response, err := e.callOpenAI(ctx, prompt)
    if err != nil {
        log.Warn("Filter engine failed, using fallback", "error", err)
        return e.getFallbackFilter(), nil
    }

    return e.parseFilterSuggestionResponse(response)
}
```

### 2. Prompt Engineering for Filter Generation

The key to reliable AI filtering is a comprehensive prompt that teaches the model Vikunja's filter syntax:

```go
func (e *OpenAIDecisionEngine) buildFilterSuggestionPrompt(request string) string {
    return fmt.Sprintf(`# Vikunja Filter Expression Builder

You are an expert at creating Vikunja filter expressions. Convert this natural language request into valid filter syntax:

## Request: %s

## Available Fields
- **done** - Task completion status (true/false)
- **priority** - Priority level (1-5, where 5 is highest)
- **due_date** - Task due date with date math support
- **labels** - Task labels/tags
- **project_id** - Numeric project identifier

## Operators & Date Math
- Comparison: =, !=, >, >=, <, <=
- Logic: && (AND), || (OR)
- Date math: now/d (today), now/w (this week), now+7d (in 7 days)

## Response Format (JSON):
{
  "filter": "done = false && priority >= 3",
  "reasoning": "Explanation of filter logic",
  "confidence": 0.95,
  "strategy": "priority_focused"
}

Respond with valid JSON only.`, request)
}
```

### 3. Robust Response Parsing with Fallbacks

Production-quality hobby systems require graceful degradation. My parser implements multiple fallback layers:

```go
func (e *OpenAIDecisionEngine) parseFilterSuggestionResponse(response string) (*models.FilterSuggestionResponse, error) {
    var aiResponse struct {
        Filter     string  `json:"filter"`
        Reasoning  string  `json:"reasoning"`
        Confidence float64 `json:"confidence"`
        Strategy   string  `json:"strategy"`
    }

    if err := json.Unmarshal([]byte(response), &aiResponse); err != nil {
        log.Warn("Falling back to basic filter due to parse error")
        return &models.FilterSuggestionResponse{
            Filter:     "done = false", // Safe fallback
            Reasoning:  "AI parsing failed, using basic incomplete tasks filter",
            Confidence: 0.3,
            Strategy:   "fallback",
            Fallback:   true,
        }, nil
    }

    // Validate and set defaults...
    return &models.FilterSuggestionResponse{
        Filter:     aiResponse.Filter,
        Reasoning:  aiResponse.Reasoning,
        Confidence: aiResponse.Confidence,
        Strategy:   aiResponse.Strategy,
        Fallback:   false,
    }, nil
}
```

## Multi-Modal Filtering: The Best of Both Worlds

My system supports both AI-generated and direct filter expressions through a unified interface:

```go
func (s Service) GetFilteredTasks(ctx context.Context, filter string, useAI bool) ([]models.Task, error) {
    finalFilter := filter
    
    if useAI {
        aiFilter, err := s.FocusEngine.SuggestFilter(ctx, filter)
        if err != nil {
            log.Warn("AI filter failed, using original", "original", filter)
        } else {
            finalFilter = aiFilter.Filter
        }
    }

    return s.Vikunja.GetFilteredTasks(ctx, finalFilter)
}
```

Users can seamlessly switch between:
- **Natural language**: `"urgent tasks due this week"`
- **Direct expressions**: `"done = false && priority >= 3"`

## Real-World Examples

### Simple Requests
```
Input:  "unfinished tasks"
Output: "done = false"
```

### Complex Temporal Logic
```
Input:  "high priority tasks due this week"
Output: "priority >= 4 && due_date >= now/w && due_date <= now/w+1w"
```

### Project-Scoped Filtering
```
Input:  "incomplete tasks in project 8"
Output: "done = false && project_id = 8"
```

## Performance & Reliability Considerations

Even for personal projects, reliability matters when you depend on the system daily.

### 1. Caching Strategy
- Cache common filter patterns to reduce API calls
- Implement request deduplication for identical queries within time windows

### 2. Error Handling
- Always provide functional fallback filters
- Log confidence scores for monitoring AI accuracy
- Implement circuit breakers for OpenAI API failures

### 3. Cost Optimization
- Use shorter, focused prompts to minimize token usage
- Implement intelligent prompt caching
- Direct filter expressions bypass AI processing entirely

## Real-World Performance

In my personal use of this system, I've found:

- **Significant time savings** when quickly filtering tasks during focus sessions
- **3-second average response time** for AI-generated filters
- **Near-perfect filter execution** thanks to robust fallback handling
- **Much less frustration** compared to manually writing filter syntax

## Key Learnings

### 1. Prompt Engineering is Critical
Investing time in comprehensive prompt engineering pays massive dividends in accuracy and reliability.

### 2. Fallbacks Aren't Optional
Production AI systems must gracefully degrade. A working basic filter beats a perfect filter that fails.

### 3. Multi-Modal Approaches Win
Power users still want direct control. Offer both AI assistance and manual precision.

## Building for One: Why Quality Matters in Personal Projects

### 1. Daily Dependence
When you use your own system every day, reliability isn't optional. A broken filter during a focus session breaks your flow.

### 2. ADHD Considerations
Poor error handling creates frustration that can derail entire work sessions. Graceful fallbacks preserve momentum.

### 3. Learning Opportunity
Building production-quality personal tools teaches patterns applicable to professional development.

### 4. Portfolio Value
Well-engineered hobby projects demonstrate technical judgment and user empathy to potential employers.

## Future Enhancements

### Learned Filter Patterns
Track which AI-generated filters I modify most often to improve future suggestions.

### Contextual Awareness
Incorporate my current project focus, time of day, and work patterns into filter generation.

### Voice Integration
Add voice input for hands-free filtering during focus sessions.

## Conclusion

AI-powered filtering transforms complex query interfaces into intuitive natural language interactions. By combining OpenAI's language understanding with solid engineering practices, I created a system that works reliably for my daily task management needs.

The key insight: **AI should enhance capability, not replace control**. My multi-modal approach proves that even personal projects benefit from providing both intelligent assistance and direct user control.

Building this system taught me that good engineering principles apply regardless of project scale. Whether it's enterprise software or a personal productivity tool, users (even if that user is yourself) deserve thoughtful, reliable experiences.

---

*This implementation is part of my ADHD-optimized task management system, designed to reduce my cognitive load while maintaining powerful functionality. The codebase demonstrates practical AI integration patterns that scale from personal projects to production systems.*

## Technical Specifications

- **AI Model**: OpenAI GPT-4
- **Backend**: Go with structured logging
- **Query Target**: Vikunja API with SQL-like filter syntax
- **Response Time**: <3 seconds for AI-generated filters
- **Fallback Strategy**: Multi-layer graceful degradation
- **Personal Project Status**: ✅ Daily use and continuously improving