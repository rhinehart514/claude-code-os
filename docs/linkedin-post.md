The hardest part of AI coding agents isn't making them write code.

It's stopping them from gaming their own scores.

Karpathy's autoresearch showed the pattern: modify, measure, keep or discard, repeat. 630 lines of Python. Autonomous ML experiments overnight. Beautiful.

But autoresearch optimizes one metric (val_bpb) on one file (train.py). Real product development isn't that clean. You need to know WHAT to build, measure MULTIPLE dimensions, remember what you tried, and catch when the AI is inflating results to look good.

So I built rhino-os — the autoresearch loop applied to product development.

What it adds:

- Strategy engine that diagnoses WHY something is broken, not just what score is low
- Two-tier scoring — fast structural lint (2 sec, every commit) + visual eval that screenshots your app and scores what it sees
- Anti-gaming guards: cosmetic-only detection, inflation caps, plateau warnings
- Meta-agent that grades the other agents and fixes broken prompts
- Experiment memory — logs what worked, what didn't, and why, so the next cycle is informed, not random
- Five agents coordinating through the filesystem. No RPC. No database. Just markdown and bash.

The part that matters: the system scored my own product NOT READY at 0.35/1.0, identified the exact bottleneck (day 3 return — users weren't coming back), and wrote a sprint plan targeting that gap.

It didn't tell me what I wanted to hear. That's the whole point.

Works natively with Claude Code. OpenClaw users can drop in the skills directly — same SKILL.md format.

MIT license. Markdown and bash.

github.com/rhinehart514/rhino-os
