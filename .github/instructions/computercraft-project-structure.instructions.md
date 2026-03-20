---
description: "Use when working on this ComputerCraft:Tweaked Lua repository, especially when creating/refactoring libraries, components, setup.lua installers, and project scaffolding. Enforces library reuse, component placement, setup.lua installability, and .templates-first structure checks."
name: "ComputerCraft Project Structure Rules"
applyTo: "**/*"
---
# ComputerCraft Project Structure Rules

- Before creating new reusable logic, check existing libraries under libs and place shared code there when it is used in multiple places.
- Prefer extending a thematically matching existing library before creating a new library.
- Keep functional scripts in the components directory. Functional scripts should consume libraries rather than duplicate shared logic.
- Every component must be installable through setup.lua. If a component cannot be installed by setup.lua, treat that as a blocker.
- When creating new libraries or components, inspect the .templates directory first and follow the template structure and naming patterns.
- Keep repository changes aligned with ComputerCraft:Tweaked Lua conventions and the project's existing API patterns.
