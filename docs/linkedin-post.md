The hardest part of AI coding agents isn't making them write code.

It's stopping them from gaming their own scores.

I've been building with Claude Code and OpenClaw for months. They're incredible at executing tasks. But they have no memory between sessions, no strategy for what to build next, and no way to know if what they built is actually good.

So they do what you'd expect — they optimize for whatever metric you give them and inflate the results.

I built rhino-os to fix this. It's a layer that sits on top of your AI coding agent and gives it:

- A strategy engine that diagnoses WHY something is broken, not just WHAT score is low
- Two-tier scoring — a fast structural lint (2 seconds, every commit) and an expensive visual eval that takes real screenshots and scores what it sees
- Anti-gaming guards: cosmetic-only detection, inflation caps, plateau warnings, stage ceilings
- A meta-agent that grades the other agents and fixes their prompts when they break
- An experiment loop that logs what worked, what didn't, and why — so the next cycle is smarter

Five agents coordinate through the filesystem. No RPC. No database. Just markdown files and bash scripts.

The whole thing is markdown and bash. MIT license.

It works natively with Claude Code. OpenClaw users can drop in the skills directly — same SKILL.md format.

The part I'm most proud of: the system scored my own product NOT READY at 0.35/1.0, identified the exact bottleneck (retention — users weren't coming back), and wrote a sprint plan targeting that gap. It didn't tell me what I wanted to hear. That's the point.

github.com/rhinehart514/rhino-os
