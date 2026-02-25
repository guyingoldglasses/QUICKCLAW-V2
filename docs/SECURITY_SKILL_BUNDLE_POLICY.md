# Skill Bundle Security Policy (Draft)

Only bundle skills that meet these checks:

1. Clear source/provenance
2. No hidden remote code fetch at runtime
3. No destructive default actions
4. Explicit credential requirements documented
5. User-opt-in install (not silently enabled)

For each bundled skill, document:
- What it does
- Required keys/accounts
- Data it reads/writes
- Risks and safeguards
