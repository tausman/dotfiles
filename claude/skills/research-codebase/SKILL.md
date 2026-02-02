---
name: research-codebase
description: ALWAYS invoke this skill (do NOT use the default Explore agent) when user asks to "research", "investigate", "explore", or "understand" the codebase. Use for understanding architecture or system design, documenting patterns or conventions, investigating how features work end-to-end, answering "how does X work?" or "where is Y implemented?" questions, preparing context before implementing changes, or exploring unfamiliar code.
---
# Research Codebase

Conduct comprehensive codebase research using parallel sub-agents.

## Process
1.  **Read mentioned files first & understand type of research**
  - Read the referenced files first FULLY (no limit/offset) before spawning tasks
  - This ensures you have necessary context before decomposing the question
  - Before starting anything, the first thing you must absolutely understand is: Is this a "general research request" about understanding a repo, service or subsystem? Or is this a "specific research request" for a specific component of a repo, service or subsystem?
2. **Decompose research question**
  - "general research request":
    - You want to focus research more on the purpose of the system itself, core components, interactions between components & interactions with other services, datastore, etc.
  - "specific research request": You want to understand everything in the "general research request" but additionally, you need to find components releated to this specific request and dive deep on how these work & interact in the context of this specific request.
  - Break into composable, independent research areas.
  - Identify components, patterns, concepts to investigate
  - Create TodoWrite research plan with specific investigation
  - **note**: "specific research requests" will have additional tasks
3. **Spawn Parallel sub-agents**
  - Use `codebase-locator` agents to find relevant files and directories
  - Use `codebase-analyzer` agents on promising findings for deep dives
  - Use `codebase-pattern-finder` for finding similar implementations or examples
  - Run multiple agents in parallel for efficiency
4. **Wait for ALL sub-agents**, then synthesize
  - Prioritize live codebase findings over thoughts/ documentation
  - Include file paths and line numbers for all references
  - Highlight patterns, architectural decisions, and design rationale
5. **Generate research document**
  - Output path: `./YYYY-MM-DD-<description>.md`
  - Use template from `~/assets/research-template.md`
  - Add GitHub permalinks if on main branch or pushed to remote
6. **Present findings to user**
  - Summarize key discoveries
  - Highlight anything surprising or noteworthy
  - Note any open questions or areas needing further investigation

