---
name: tdd-strict
description: Enforce strict Test-Driven Development (TDD) cycle. Use whenever writing new features, fixing bugs, or implementing use cases.
---
# Strict TDD Workflow

You MUST follow the Red-Green-Refactor cycle for any code implementation:
1. **RED:** Write a failing test first. Use the AAA pattern (Arrange, Act, Assert). Ensure the test names follow the convention: `should_[expected_behavior]_when_[condition]`.
2. **GREEN:** Write the minimal code required to make the test pass.
3. **REFACTOR:** Improve the code without changing behavior.
Do not write implementation code without a failing test.