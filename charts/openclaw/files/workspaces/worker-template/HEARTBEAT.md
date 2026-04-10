Create this file only when the approved worker definition explicitly uses heartbeat.

For heartbeat-enabled workers:
- keep the run narrow, cheap, and procedural
- execute only the approved trigger-checking workflow
- escalate to main when the rule package says the gate is met
- update `CURRENT.md`, the latest daily note, and any explicitly granted shared Nextcloud `/Desk/` entry only when the worker definition says continuity is needed for future runs
