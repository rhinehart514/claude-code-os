I built a system where 5 AI agents grade each other's work, catch when one is silently broken, and fix their own prompts. No human in the loop for any of that. Here's the real data from it running. [attach PDF]

It's called rhino-os. It gives AI coding agents like Claude Code or OpenClaw the thing they're missing — a brain. Strategy for what to build next, scoring to know if what they built is actually good, and memory so they're not starting from scratch every session.

Karpathy just dropped autoresearch and it's brilliant — same core idea. Write instructions in markdown, let AI experiment autonomously, keep what works, discard what doesn't. You're not writing code. You're programming the program.

But here's the thing that I don't think people are talking about enough:

autoresearch works beautifully because ML training has an objective metric. val_bpb goes down or it doesn't. There's no arguing with it. No gaming it. The number is the truth. That's what makes the keep/discard loop so clean.

Product development doesn't have that. "Is this better?" is fundamentally a subjective question. You're measuring taste, usability, whether someone comes back on day 3, whether the thing you built actually solves the problem you think it does. There's no single loss function you can point at and say "this went down, ship it."

And here's what nobody warns you about — when you give AI agents subjective metrics, they WILL game them. I watched it happen repeatedly. Move some comments around, rename a variable, restructure some whitespace, claim an improvement. The agent isn't lying — it genuinely found a way to make the number go up. The number just doesn't mean anything.

So the real problem isn't the loop. The loop is the easy part. Modify, measure, keep or discard — that's like 50 lines of logic. The real problem is: how do you build a scoring system for subjective quality that an AI can't BS its way through?

That's where I think domain expertise becomes the bottleneck — and honestly the thing that makes this approach valuable rather than just another framework.

You can't slap a generic "rate this 1-10" evaluator on a product and expect useful signal. The scoring rubric has to encode what YOU know about your domain. What does "good" actually look like for your specific product? What are the failure modes? What does your specific user actually care about? A generic AI can't answer these questions. You have to.

What I landed on is two-tier scoring — a fast objective check that runs every commit (grep-based, 2 seconds, catches real breakage) plus a slow subjective visual eval that takes actual Playwright screenshots and scores what it sees across 9 dimensions. The gap between the objective score and the subjective score is where the real signal lives. Both projects passed structural checks. Both scored 1/5 on taste because routes were broken in production. Structural scoring said fine. Visual eval said broken. That divergence is the entire point of running both.

Then there are anti-gaming guards on every subjective touchpoint because without them the whole system produces garbage. Cosmetic-only detection — did anything real actually change? Inflation caps — score jumped 15 points in one commit? nah. Plateau warnings. Stage ceilings so your MVP can't magically score 95/100.

What works well:

The self-healing. A meta-agent grades the other agents periodically. At one point 3 of 5 agents were silently crashing for two days. Nobody knew. Meta caught it, diagnosed the root cause, fixed the prompts, brought all 5 back online.

The experiment loop compounding over time. Identity score went from 0.30 to 0.63 in 17 experiments. Copy changes plateaued at 0.44 — the system recognized the plateau and shifted to visual identity changes which pushed further. One experiment was discarded because it improved the score but violated the product's constraints. That's the kind of judgment call I didn't expect the system to make.

What's still messy:

The cold start. First run on a new project, the system knows nothing. No taste signals, no experiment history, no market context. Gets smarter fast but that first cycle is rough.

Prompt fragility. The agents are only as good as their markdown instructions. One bad sentence in a program.md and an agent goes sideways for an entire session. Meta catches this eventually but not instantly.

The discard rate is 4.6% when it should be closer to 40%. The system flags this correctly but I haven't solved it yet. An experiment loop that rarely fails isn't experimenting — it's committing.

The bigger idea I keep coming back to: the next wave of useful AI tooling is going to come from people who deeply understand a specific domain and encode that knowledge into agent instructions and scoring rubrics. Not from general-purpose frameworks trying to do everything. Karpathy knows ML training cold, so autoresearch works. Your version of this should encode what you know cold. The objective loop is solved. The subjective loop — measuring quality in domains where "better" is a judgment call — is wide open.

Open source. Five agents, filesystem coordination, bash and markdown. Works with Claude Code natively, OpenClaw users can drop in the skills.

If you're building with AI agents and want to pressure test this, DM me. Genuinely curious what breaks when someone else runs it.

github.com/rhinehart514/rhino-os
