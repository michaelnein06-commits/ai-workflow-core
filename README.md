# Isolated-agent AI coding workflow

My current AI coding workflow. Used with Codex CLI and GPT5.2 high-reasoning. 

Core Principles 
- Isolated agents for different responsibilities that are designed to critique each others work to deliver better solutions and isolated context to reduce bias and hallucinations. 
- Automated workfow. The entire workflow is completely automated for AI-only dev teams. The only human input required is in PRD workflow to gather and brainstorm your requirements. I have made this process overly detailed to minimize the room for misunderstanding. 
- Clear & Plain English: I actively work on 20-30 github issues concurrently with this workflow, so the agents communicate in clear and unambiguous english giving context and required information when they communicatewith you to avoid you needing to reference back to the GH issues. 
- Isolated Woktrees to allow working in parralel. 

Tools I use
- Codex CLI
- GH CLI 
- Warp for terminal management 
- CodeRabbit & Cubic.dev for CI code reviews
- Ruff

## The two commands
This repo intentionally focuses on **only**:
- `prd`: convert a vague idea into a decision-complete PRD/EPIC with specific use cases, requirements and acceptance criteria
- `impl`: orchestrate agent launches sub agents: Dev → QA → Merge for a GitHub issue in an isolated worktree. Dev -> QA communicate and loop until all requirements and acceptance criteria are met. 


## Quickstart
1) Install prerequisites
- Zsh
- `git`
- `gh` (GitHub CLI)
- `codex` CLI (or your agent runner)

2) Install/link the skills
```bash
./scripts/install-skills.sh
```

3) (Optional) Validate setup
```bash
./scripts/doctor.sh
```

4) Source the Zsh commands (add to your `~/.zshrc`)
```bash
source /path/to/ai-coding-workflow/zsh/ai-coding-workflow.zsh
```

## Usage
### PRD
```bash
prd "Draft an EPIC for: add X, remove Y, and keep Z unchanged"
```

### Implementation orchestrator
```bash
impl 123 "Keep it minimal; prove it with E2E"
```


## What’s in here
- `zsh/ai-coding-workflow.zsh`: the `prd` + `impl` commands
- `prompts/`: the prompt templates those commands inject
- `skills/`: the “skills” referenced by the prompts

## Security
This repo intentionally does **not** include secrets.
- do not commit `.env*`
- do not hardcode tokens in prompts

## License
MIT (see `LICENSE`).
