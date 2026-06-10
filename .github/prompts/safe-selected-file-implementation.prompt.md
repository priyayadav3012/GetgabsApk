---
description: "Work a selected-file task safely, with confirmation before edits"
argument-hint: "[TASK-ID] task name, selected file, and any constraints"
agent: "Flutter Architect"
---
You are working from a selected file and a generic task identifier.

Rules:
- Treat the task number as a placeholder, not a fixed audit ID. Use `[TASK-ID]` in any log or filename references.
- Review the selected file first, then only the nearest related code needed to understand the change.
- Identify one falsifiable local hypothesis and one cheap check before any edit.
- Always ask for confirmation before making changes.
- Do not modify audit documents or TODO list files.
- If changes are approved, record them in a dedicated `[TASK-ID]_change_log.md` file.
- Keep edits minimal, local, and consistent with the existing code style.

Output:
- Summarize the local hypothesis and the planned change.
- Ask for confirmation before editing.
- If approved, apply the smallest safe fix and note the outcome in the change log file.