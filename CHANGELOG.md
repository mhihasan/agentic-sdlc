# Changelog

All notable changes to coding-agent-skills are documented here.

## Unreleased

### Added
- **Self-review gates** at every artifact boundary: `fetching-tickets`, `generating-tasks`, `crafting-commits` — objective/mechanical checklists the producing skill runs before handoff
- **Deepened `planning-from-ticket` self-review** — added grounding-verified check (every named file/function was actually read in step 2)
- **Mode contract** across the full pipeline — every skill now accepts `auto` argument; collaborative is the default; `auto` relaxes forward-progress pauses but never relaxes git writes or judge halts
- **Fresh-context judge subagents** in `reviewing-plan` and `reviewing-code` — judges run on a strong model with only the artifact + ticket + rubric, no prior conversation context (self-preference bias guardrail)
- **Verdict marker** in `reviewing-plan` — emits `> **Plan Review:** PROCEED — date` to the PLAN file after a PROCEED verdict (the signal `implementing-tasks` checks)
- **Hard gate in `implementing-tasks`** — refuses to start without a `reviewing-plan` verdict marker in the plan file
- **`crafting-commits` as mandatory pipeline step** — reframed from optional to required before `finishing-a-development-branch`
- **Mermaid pipeline diagram** in README — replaces ASCII art; colour-coded nodes, dotted fix-and-retry edges
- **Review tiers**, **mode contract**, and **recommended model tiers** tables in README
- MIT LICENSE file
- CONTRIBUTING.md
- GitHub issue templates (bug report, skill request)

### Changed
- `reviewing-plan` Core Principle updated: "the user must approve" → mode-aware ("a plan must be reviewed before it's trusted"; in `auto`, the independent judge replaces the human chat-gate)
- `reviewing-code` Next Steps: `crafting-commits` changed from suggestion to mandatory gate
- README: hook rewritten, quickstart added, superpowers sub-skills table added, repo renamed to `coding-agent-skills`

## [0.4.0](https://github.com/mhihasan/agentic-sdlc/compare/v0.3.0...v0.4.0) (2026-06-30)


### Features

* **evals:** add eval harness ([1eaf80a](https://github.com/mhihasan/agentic-sdlc/commit/1eaf80a7394b7728a7cc1ded0de13610a15f296f))
* **fetching-tickets:** add MCP path as primary for OAuth users ([447b3f8](https://github.com/mhihasan/agentic-sdlc/commit/447b3f82ffc9e2b0c7060bbb43f14caf23da33fb))
* **fetching-tickets:** add MCP path as primary for OAuth users, curl as fallback ([68dd08e](https://github.com/mhihasan/agentic-sdlc/commit/68dd08ec2db9f4b8799d1ffe984fa870dd15a7a4))
* **install:** add --tag flag to pin install to a specific release ([62251f7](https://github.com/mhihasan/agentic-sdlc/commit/62251f7f04ddb2ef83b464de00a16bf93b966e26))
* **install:** add --tag flag to pin install to a specific release ([29f1437](https://github.com/mhihasan/agentic-sdlc/commit/29f143789dbc97c4e4ddcc94a2f8756b2e320781))
* **install:** add --tool=opencode support ([089b846](https://github.com/mhihasan/agentic-sdlc/commit/089b84658a0cde1406f3c19b8e6553c16cad37cd))
* **install:** add --tool=opencode support for ~/.config/opencode/ ([c5d5ae1](https://github.com/mhihasan/agentic-sdlc/commit/c5d5ae1fd46ec030b68e30bdfbba9acbf020a77b))
* standalone skills, eval harness, and 11 skill scenarios ([dd4734d](https://github.com/mhihasan/agentic-sdlc/commit/dd4734d4dda05935e4a3cd6fff19facb7f871b26))


### Bug Fixes

* **ci:** exclude eval fixtures and SKILL-BEST-PRACTICES from link checker ([e6ea29a](https://github.com/mhihasan/agentic-sdlc/commit/e6ea29a4de22bfbf274c9e6d0917422305ad9a3b))
* **ci:** exclude eval fixtures and SKILL-BEST-PRACTICES from link checker ([5f298e9](https://github.com/mhihasan/agentic-sdlc/commit/5f298e9637e8a859dd84290b3de5b5ee8c35b62c))
* **ci:** lychee toml fix, eval validation, install --tag support ([a5dfded](https://github.com/mhihasan/agentic-sdlc/commit/a5dfdeda57798814068e45f4a3cf97f6c038df5e))
* **ci:** remove invalid [output]/[options] sections from .lychee.toml ([d2a7726](https://github.com/mhihasan/agentic-sdlc/commit/d2a77263a074ce71047264f8199bc91287e24923))
* **ci:** wire lychee config and add eval schema validation ([5a0ebcf](https://github.com/mhihasan/agentic-sdlc/commit/5a0ebcf7d7ffd9e1b6cc3fc2b893074b09153b94))
* **ci:** wire lychee config and add eval schema validation ([a1ddbb1](https://github.com/mhihasan/agentic-sdlc/commit/a1ddbb1aabf35422ea104a1567ca15d476a445e2))
* **fetching-tickets:** hybrid MCP+curl for images, clear note when token absent ([f056e05](https://github.com/mhihasan/agentic-sdlc/commit/f056e050672f19c0375978a7a6130a0ce930b7ba))
* **generating-tasks:** explicitly forbid /tdd handoff, name exact next command ([9df5710](https://github.com/mhihasan/agentic-sdlc/commit/9df5710db9ff94a821fd2c7cab705a59508c6df3))
* **install:** auto-remove broken symlink at commands target dir inste… ([f371948](https://github.com/mhihasan/agentic-sdlc/commit/f37194820a7b036e4b793d4f6148bbaea3bbbe2a))
* **install:** auto-remove broken symlink at commands target dir instead of skipping ([abea59d](https://github.com/mhihasan/agentic-sdlc/commit/abea59d09c56b551790ae04978a713e9ad11aeed))
* **install:** link commands/references/ so relative paths resolve ([37d4c54](https://github.com/mhihasan/agentic-sdlc/commit/37d4c546786a10614c4822a4c3fb09cc1fb49fe2))
* **install:** link commands/references/ subdir so relative paths resolve ([a586053](https://github.com/mhihasan/agentic-sdlc/commit/a5860532d52861295a57ae2920ea289c3adbfa1b))
* **install:** replace managed skill dirs with symlinks, handle broken commands symlink, drop stale superpowers check ([bc06df6](https://github.com/mhihasan/agentic-sdlc/commit/bc06df6b3ef7893704513200ca566cb0bcb441b8))
* rename swe-skills → swe-agent-skills, forbid /tdd handoff in generating-tasks ([4ba6a9b](https://github.com/mhihasan/agentic-sdlc/commit/4ba6a9b43b7076fe95b0e09d4fb31a7b4ceb6b2e))
* **sdlc-start:** inline reference content, remove external file dependency ([8e30d6b](https://github.com/mhihasan/agentic-sdlc/commit/8e30d6b8f00ef5a30d20796cd1e20d0c01ab5f2a))
* **sdlc-start:** inline reference content, remove external file dependency ([ea96a64](https://github.com/mhihasan/agentic-sdlc/commit/ea96a64b258000e6c723a492e849f3f416b95f62))
* **simulator:** add YOU APPROVE gate to planning-from-spec step ([e24c458](https://github.com/mhihasan/agentic-sdlc/commit/e24c4584444e745db2416152a6226042fd19f7d4))
* **simulator:** add YOU APPROVE gate to planning-from-spec step ([d57b086](https://github.com/mhihasan/agentic-sdlc/commit/d57b086b510b4a39507a5a164cf48e373e096dce))


### Reverts

* **generating-tasks:** restore to main ([d232981](https://github.com/mhihasan/agentic-sdlc/commit/d232981a9225d295d097b2411e6ebc76b3ff3c06))

## [0.3.0](https://github.com/mhihasan/agentic-sdlc/compare/v0.2.0...v0.3.0) (2026-06-20)


### Features

* add --tool flag to install.sh for Claude and Copilot support ([eb2b6d9](https://github.com/mhihasan/agentic-sdlc/commit/eb2b6d90c45998d1a68429de7e0eabb7a900d419))
* add commands/ source directory ([8a31bc9](https://github.com/mhihasan/agentic-sdlc/commit/8a31bc96a87ffcdc2a652132e0d19a2142d449bb))
* add sdlc-start universal pipeline entry command ([f8664ac](https://github.com/mhihasan/agentic-sdlc/commit/f8664ac353422b78b9d425863efcd2c77b777ffb))
* add start-task skill ([c9500c3](https://github.com/mhihasan/agentic-sdlc/commit/c9500c3a26f09810e349b3fc4f7bf5f973d28b6c))
* **crafting-commits:** add preflight gate check and formal REVIEW-LOG stamp at Step 5 ([7b17169](https://github.com/mhihasan/agentic-sdlc/commit/7b17169b6680233dbb5ea36adbef36943d6fe012))
* **crafting-commits:** delete active state file on pipeline completion ([e3cdc75](https://github.com/mhihasan/agentic-sdlc/commit/e3cdc75bda8f4f940fb6a4b64b728f7137a1f3ff))
* **crafting-commits:** instruct draft PR creation when invoking finishing-a-development-branch ([866769a](https://github.com/mhihasan/agentic-sdlc/commit/866769ab7694cf28aa871f5e350d75ce3a631ac6))
* curl-pipe one-liner install + README updates ([8d5f632](https://github.com/mhihasan/agentic-sdlc/commit/8d5f632c0bf0c72d39b824906dbc7f01aebd9f68))
* **de-slop:** add de-slop skill ([a1cf25d](https://github.com/mhihasan/agentic-sdlc/commit/a1cf25dcd4ef06a29f6a0fc5ccaaf4d770bb1f92))
* **de-slop:** add de-slop skill and strip AI footprint from README ([7d22d9d](https://github.com/mhihasan/agentic-sdlc/commit/7d22d9d645e143e07bfe588dc7d3eb0ae939d8b6))
* **docs:** add interactive pipeline simulator + GitHub Pages hosting ([0bef057](https://github.com/mhihasan/agentic-sdlc/commit/0bef05774d87da1fde50f0ef25fc34501e862254))
* extend install.sh to link commands/ alongside skills/ ([1d1fad9](https://github.com/mhihasan/agentic-sdlc/commit/1d1fad94ef25e4406bdc4fb7c86047f7237ee3f8))
* **generating-tasks:** add preflight gate check and REVIEW-LOG stamp ([a1ebc90](https://github.com/mhihasan/agentic-sdlc/commit/a1ebc9096ab6fb9273554dedf0e5b0f4fc269c72))
* **generating-tasks:** update active state on completion ([5efce7f](https://github.com/mhihasan/agentic-sdlc/commit/5efce7f53554abec6babb069473181e431da7e88))
* **implementing-tasks:** add preflight gate check and per-task review gate ([a5c9c63](https://github.com/mhihasan/agentic-sdlc/commit/a5c9c63f61bdcaa45b73dfe1a85d1f620b591d7e))
* **implementing-tasks:** track current task and advance active state on completion ([bae7ff2](https://github.com/mhihasan/agentic-sdlc/commit/bae7ff243a47103f3f07f70a71e16f9d48ba178e))
* install.sh supports user, project, or both scope ([0489e00](https://github.com/mhihasan/agentic-sdlc/commit/0489e00efaf0f11d887c98382b64f41dd676d202))
* **models:** pin model per skill, update README model table ([6a0cd76](https://github.com/mhihasan/agentic-sdlc/commit/6a0cd767938e69c9092ae85f15a8d2907f4a1e26))
* **models:** pin model per skill, update README model table ([219bd3b](https://github.com/mhihasan/agentic-sdlc/commit/219bd3bfb406dbd50a79aa307b1704b951ce3668))
* **picking-up-task:** add review gate and REVIEW-LOG stamp at handoff ([03e04af](https://github.com/mhihasan/agentic-sdlc/commit/03e04af37be1a3122f283d4ff8a2a48069716f06))
* **picking-up-task:** ask for artifacts root on first run, default local-dev/tickets, store in .claude/artifacts-root ([3352f88](https://github.com/mhihasan/agentic-sdlc/commit/3352f88d5856ea05780311a147e258ce0a5c2f73))
* **picking-up-task:** read config from .agentic-sdlc/, write active state on completion ([ae87c87](https://github.com/mhihasan/agentic-sdlc/commit/ae87c8784d294bca1507426869a963cf31f0e9b2))
* **pipeline:** add human review gates to all artifact boundaries ([d41c827](https://github.com/mhihasan/agentic-sdlc/commit/d41c8271e8521de5cf00fc36800ba75794cb2853))
* **pipeline:** migrate artifact root from tickets/ to local-dev/tickets/ and add global gitignore setup ([2792f63](https://github.com/mhihasan/agentic-sdlc/commit/2792f63da3afe32d118c1304964bcc914c440b21))
* **planning-from-spec:** update active state on completion ([1a429c3](https://github.com/mhihasan/agentic-sdlc/commit/1a429c3e303c44db31b5c86bda719d7e5588b202))
* **planning-from-ticket:** add preflight gate check and REVIEW-LOG stamp ([58eaa67](https://github.com/mhihasan/agentic-sdlc/commit/58eaa675df7bfa6e249370b5b0e87650a61762cf))
* rename planning-from-ticket to planning-from-spec ([bf9c9b0](https://github.com/mhihasan/agentic-sdlc/commit/bf9c9b0aff30ae8b6fec7cfa14c439c5ddcf9be2))
* reviewing-code reads ticket file alongside plan in pipeline mode ([2288fd0](https://github.com/mhihasan/agentic-sdlc/commit/2288fd00c2468ebfbf2330891c052000177d3b81))
* **reviewing-code:** add preflight gate check and review gate after report ([7f2dd79](https://github.com/mhihasan/agentic-sdlc/commit/7f2dd79a632952e9f0e2b24f83f463dd5927addd))
* **reviewing-code:** update active state on completion ([edd81a3](https://github.com/mhihasan/agentic-sdlc/commit/edd81a3b8d93c341efa5352a9fb495887d709b56))
* **reviewing-plan:** add preflight gate check and human review gate after AI verdict ([8dd9378](https://github.com/mhihasan/agentic-sdlc/commit/8dd9378561c25d34fd431e6cd4772560507bb170))
* **reviewing-plan:** update active state on completion ([ed18e11](https://github.com/mhihasan/agentic-sdlc/commit/ed18e1197236ff265145b3bfc656deef73c302b2))
* sdlc-start universal entry, dotfolder active state, interactive pipeline simulator ([65e65a2](https://github.com/mhihasan/agentic-sdlc/commit/65e65a217246a700e031c6a2bbf6406985dd8ae9))
* **sdlc-start:** propagate auto/collaborative mode to all downstream skills ([a2b04e9](https://github.com/mhihasan/agentic-sdlc/commit/a2b04e94fce5ce4b57024c2db8b2969c2f526981))
* **sdlc-start:** usage reference file and auto mode propagation ([10258c1](https://github.com/mhihasan/agentic-sdlc/commit/10258c1cab358a6b246a16574e1228441d705dfd))
* support curl-pipe remote install in install.sh ([f1cb8a5](https://github.com/mhihasan/agentic-sdlc/commit/f1cb8a5dba5108eb583377c28debf2d76632b0c5))


### Bug Fixes

* align skills with writing-skills best practices ([70dbd2d](https://github.com/mhihasan/agentic-sdlc/commit/70dbd2de42c0f43574efb04d48a5da87456ac7b9))
* clean up partial clone dir on failed git clone ([97b36ee](https://github.com/mhihasan/agentic-sdlc/commit/97b36ee1670ce445279aadeae6736bbcfcea1299))
* correct BASH_SOURCE detection and improve pull failure message ([517a861](https://github.com/mhihasan/agentic-sdlc/commit/517a86101a1f3a1cf20cbc5eea91daea01f075e7))
* **crafting-commits,fetching-tickets,receiving-plan-review,testing-pytest,testing-vitest:** add model/color/license frontmatter fields ([1d9510e](https://github.com/mhihasan/agentic-sdlc/commit/1d9510e8ad075a5cd148f84b25d1907e99eecfc1))
* **crafting-commits,generating-tasks,receiving-plan-review,testing-vitest:** trim body openers to single sentence ([dc31088](https://github.com/mhihasan/agentic-sdlc/commit/dc31088c3844b8a6dece4b05f133e86c35de79f0))
* **crafting-commits:** ask yes/no before invoking finishing-a-development-branch ([43bb54a](https://github.com/mhihasan/agentic-sdlc/commit/43bb54a10dc6ff3c19ea6598bd8a119dd6a7d41a))
* **crafting-commits:** fast-path when all commits are already clean ([56a9040](https://github.com/mhihasan/agentic-sdlc/commit/56a90402291e6636f9d444101a3fdbc58c29eb22))
* **crafting-commits:** fetch and sync remote tracking branch before rebase ([bd6c988](https://github.com/mhihasan/agentic-sdlc/commit/bd6c9885540ed2edb55b14530a4d1e785b7f6f9c))
* **crafting-commits:** rebase onto target branch before evaluating commits ([1e0a6dc](https://github.com/mhihasan/agentic-sdlc/commit/1e0a6dcf2a26e3878e4be68ed825b04d82153a3c))
* exclude Release Please compare URLs from lychee link checker ([4e9c649](https://github.com/mhihasan/agentic-sdlc/commit/4e9c64900866fe74246b20b46006aa66119003b2))
* exclude Release Please compare URLs from lychee link checker ([139e169](https://github.com/mhihasan/agentic-sdlc/commit/139e169401e16c82533f66b2ce393f3dbea1e0cf))
* **fetching-tickets,generating-tasks,crafting-commits,reviewing-code:** document all four auto mode invariants explicitly ([d41e34b](https://github.com/mhihasan/agentic-sdlc/commit/d41e34bf0cfca488a3ba382125978adf911ad999))
* **fetching-tickets:** replace start-task with picking-up-task in description ([4b09557](https://github.com/mhihasan/agentic-sdlc/commit/4b095573acba3e52c792483f9ab973aacf74e811))
* **generating-design-doc:** rewrite description as trigger-focused, remove body duplication, strengthen self-review gate ([c034e87](https://github.com/mhihasan/agentic-sdlc/commit/c034e87e8dfd931dc77ea69f9b11900727eebf14))
* **generating-tasks,picking-up-task:** remove scope-delimiting clauses from descriptions ([8257106](https://github.com/mhihasan/agentic-sdlc/commit/8257106f05b8d4a3a08c6a28b13d954d573e3c03))
* guard against infinite re-exec and unknown flag silent swallow ([6d81a24](https://github.com/mhihasan/agentic-sdlc/commit/6d81a243c233117f7b4e3069acd7f9deaac19543))
* handle partial clone dir and reuse \$here for REPO_DIR ([e1f7855](https://github.com/mhihasan/agentic-sdlc/commit/e1f78551c228fbfc11e8514f689e6bf736efa97f))
* **implementing-tasks:** canonical plan file name in examples, trim description, add license ([b5beede](https://github.com/mhihasan/agentic-sdlc/commit/b5beeded1c7c3d86bf639b136c487d348dbc001c))
* **implementing-tasks:** replace start-task with picking-up-task in body ([ecbab2e](https://github.com/mhihasan/agentic-sdlc/commit/ecbab2eef288f02a8fb13d1e2d81a931c34c2d9b))
* improve diagram labels for reviewing-code fail path and finishing-a-development-branch ([3056f5b](https://github.com/mhihasan/agentic-sdlc/commit/3056f5bfed501f854ba392ef0d767b26cce87432))
* **install.sh:** guard missing commands/ dir, update usage text ([3cd2a60](https://github.com/mhihasan/agentic-sdlc/commit/3cd2a6025288360f0778ddc9bb634e902d3d708f))
* make --scope required in install.sh, remove silent default ([2accdad](https://github.com/mhihasan/agentic-sdlc/commit/2accdadeb5b1b372e6701892df6f175480328fac))
* **picking-up-task:** add license, fix bash gitignore one-liner, rename H1 to picking-up-task ([ebb8e0f](https://github.com/mhihasan/agentic-sdlc/commit/ebb8e0fe331686c2d037021ffd26fe72e3a12c43))
* **picking-up-task:** replace deprecated start-task name with picking-up-task in pipeline diagram ([a6afd4e](https://github.com/mhihasan/agentic-sdlc/commit/a6afd4e9efea8f2583de26821746fbdf2bb77d97))
* **planning-from-ticket:** correct stamp format to use blockquote+bold prefix ([6a33a0e](https://github.com/mhihasan/agentic-sdlc/commit/6a33a0ebfc8f3946675dd733aa8b1f1e0dd1d8f2))
* **planning-from-ticket:** trim description to trigger-only, add model/color frontmatter, strengthen self-review gate ([08411bc](https://github.com/mhihasan/agentic-sdlc/commit/08411bcbdc595abad18ff142b5fa19e99ea678c5))
* **readme:** add missing human gate after planning-from-ticket in flowchart ([2d6cf39](https://github.com/mhihasan/agentic-sdlc/commit/2d6cf3981e3059516e2975a81ff7e524d38defbb))
* **readme:** restore Design Principles as standalone section before Use Cases ([2cc93d1](https://github.com/mhihasan/agentic-sdlc/commit/2cc93d13ad03abaf00a749d0329d6ed574878eb6))
* remove --scope=both from install.sh ([98384f9](https://github.com/mhihasan/agentic-sdlc/commit/98384f9623f197a6cbfa9cbf6811644120138aeb))
* remove incorrect self-review marker from start-task diagram node ([d564f63](https://github.com/mhihasan/agentic-sdlc/commit/d564f63b68dc892334718229d171be5ace526df6))
* remove self-review tick markers from pipeline diagram ([f014be9](https://github.com/mhihasan/agentic-sdlc/commit/f014be9bdcb7eb7f3cd983e64ec7a10fb44d0be9))
* require explicit project path for --scope=project ([3635da0](https://github.com/mhihasan/agentic-sdlc/commit/3635da006a808929614a99861be519b50986170e))
* **reviewing-code:** add self-review gate on report artifact before delivery ([8307f3d](https://github.com/mhihasan/agentic-sdlc/commit/8307f3d6f6bdaac2622da9407f0290a216b8600e))
* **reviewing-code:** update bare tickets/ path example to local-dev/tickets/ ([7dc7ccf](https://github.com/mhihasan/agentic-sdlc/commit/7dc7ccf6c0950cf7ef43d570fc4459b3c3544e02))
* **reviewing-plan,implementing-tasks:** align PROCEED marker contract to accept both PROCEED and PROCEED WITH CHANGES ([ee04804](https://github.com/mhihasan/agentic-sdlc/commit/ee048043b47c7bfec2c052c5097ada81978c78f1))
* **reviewing-plan:** rewrite description as trigger-focused, add model/color/license frontmatter ([3ea68e7](https://github.com/mhihasan/agentic-sdlc/commit/3ea68e76f6d083b14ab992ad8bc7a0781d27f42f))
* **skills:** align descriptions and body with writing-skills best practices ([a6e4cd7](https://github.com/mhihasan/agentic-sdlc/commit/a6e4cd72b80377702ee4637324799b912d21ac22))
* **skills:** skill best practices, install simplification, SKILLS.md restore ([8d73a06](https://github.com/mhihasan/agentic-sdlc/commit/8d73a06a33032c8eacc3d96101d44d7e75cb942b))


### Reverts

* remove PLAN file schema from reviewing-code skill ([df6d5cb](https://github.com/mhihasan/agentic-sdlc/commit/df6d5cbd53ac6f74b366e577128e0c53858e360c))

## [0.2.0](https://github.com/mhihasan/coding-agent-skills/compare/v0.1.0...v0.2.0) (2026-06-16)


### Features

* write commit plan to ticket directory when ticket dir exists ([b8e0da9](https://github.com/mhihasan/coding-agent-skills/commit/b8e0da97a8081314eb4b254f4705610082970f60))


### Bug Fixes

* replace shields.io badges with badgen.net ([2d7f5be](https://github.com/mhihasan/coding-agent-skills/commit/2d7f5becc7143650518548a845759b93c3a6da03))
* replace shields.io badges with badgen.net to avoid token pool errors ([ef61277](https://github.com/mhihasan/coding-agent-skills/commit/ef6127771ac275fd99b73a48253573de0e3474cf))

## [0.1.0](https://github.com/mhihasan/coding-agent-skills/compare/v0.0.1...v0.1.0) (2026-06-16)


### Features

* add Claude plugin manifest and marketplace for distribution ([e43fea7](https://github.com/mhihasan/coding-agent-skills/commit/e43fea7896243c64256f430e7d021a3aee80aafa))
* add Claude plugin manifest and marketplace for distribution ([0606d61](https://github.com/mhihasan/coding-agent-skills/commit/0606d61ce81bb7c2ff532bdcc27cfd24c9305cce))


### Bug Fixes

* disable MD004 for Release Please generated CHANGELOG ([1a2eaec](https://github.com/mhihasan/coding-agent-skills/commit/1a2eaec1a69bad543177e7513baba309ee0a16a4))
* disable MD004 for Release Please generated CHANGELOG ([bc8db49](https://github.com/mhihasan/coding-agent-skills/commit/bc8db495f948ae0fc1e4dd075e7377082450995a))
* resolve pre-commit linting failures ([cb91702](https://github.com/mhihasan/coding-agent-skills/commit/cb91702edf26f6a48af4f2f1b553213c7923220f))
* silence noisy markdownlint rules; fix broken TOC link ([6dc3f7a](https://github.com/mhihasan/coding-agent-skills/commit/6dc3f7a817f1b8fa0144648f1040c959315a3ef8))
* silence noisy markdownlint rules; fix broken TOC link in component-patterns ([75e3449](https://github.com/mhihasan/coding-agent-skills/commit/75e34493d7fb697e727d1e2642cf3e1f7f877536))

## 0.1.0 — Initial release

Pipeline skills: `fetching-tickets`, `planning-from-ticket`, `generating-tasks`, `reviewing-plan`, `implementing-tasks`, `reviewing-code`, `crafting-commits`.

Craft skills: `clean-architecture`, `clean-coding`, `ddd-expert`, `design-patterns-expert`, `design-doc-generator`, `pragmatic-engineer`, `system-designing`, `pytest-expert`, `vitest-react`.

Superpowers integration: `brainstorming`, `writing-plans`, `test-driven-development`, `systematic-debugging`, `verification-before-completion`, `requesting-code-review`, `receiving-code-review`.
