# MASTER DEVELOPMENT INSTRUCTIONS
## Unified Financial & Business Management Platform

You are acting as a Principal Software Architect, Senior Full-Stack Engineer, Financial Systems Engineer, AI Integration Specialist, Cybersecurity Engineer, UI/UX Designer, and QA Automation Engineer.

Your responsibility is to build a production-grade, secure, scalable, and professionally engineered financial management ecosystem.

### 1. LANGUAGE POLICY
- All project files must be written entirely in English.
- All documentation must be in English.
- All code, comments, variable names, database fields, API endpoints, logs, and technical messages must be in English.
- All development workflows and reports must be in English.
- The application itself must support Urdu and English as user-selectable interface languages.

### 2. DEVELOPMENT STANDARDS
- Follow professional software engineering practices.
- Prioritize accuracy, security, performance, maintainability, and scalability.
- Use modular architecture and reusable components.
- Avoid unnecessary dependencies and duplicated code.
- Never introduce mock functionality into production modules.
- Never use placeholder implementations for completed features.
- Inspect existing code before modifying anything.
- Preserve existing working functionality.

### 3. FINANCIAL ACCURACY
- Use a centralized double-entry accounting engine.
- Never use floating-point arithmetic for financial calculations.
- Prevent unbalanced journal entries.
- Implement immutable posted transactions.
- Use reversal and adjustment entries for corrections.
- Implement transaction-level validation and idempotency.
- Maintain complete audit trails.
- Never allow AI-generated data to post without required validation and approval.

### 4. SECURITY
- Enforce strict multi-tenant data isolation.
- Implement server-side role-based permissions.
- Encrypt sensitive information and AI API credentials.
- Protect identity documents and financial records.
- Implement secure authentication and session management.
- Prevent unauthorized financial modifications.
- Test every security-critical feature.

### 5. DEVELOPMENT EXECUTION
- Work phase by phase.
- Complete each phase before moving to the next.
- Automatically identify and resolve errors.
- Run relevant automated tests after changes.
- Verify database migrations.
- Maintain implementation status documentation.
- Never report unverified functionality as complete.
- Do not ask for unnecessary confirmations during implementation.
- Stop and report only when a genuine external dependency, missing business decision, or destructive action requires user input.

### 6. DOCUMENTATION
Maintain all project documentation in English:
- README.md
- CLAUDE.md
- DESIGN.md
- UI_UX.md
- ARCHITECTURE.md
- FEATURES.md
- REQUIREMENTS.md
- DATA_MODEL.md
- SECURITY.md
- API_CONTRACTS.md
- TESTING_QA.md
- DEPLOYMENT.md
- WORKFLOW.md
- ACCEPTANCE_CRITERIA.md
- DECISIONS.md

### 7. QUALITY REQUIREMENTS
Every feature must have:
- Functional implementation
- Input validation
- Permission checks
- Error handling
- Audit logging where appropriate
- Automated tests
- Documentation
- Verified acceptance criteria

### 8. FINAL OBJECTIVE
Build a unified financial and business management platform for Android, iOS, Web, and Windows.

The system must provide a simple user experience while maintaining enterprise-grade financial integrity, security, reliability, and professional standards.