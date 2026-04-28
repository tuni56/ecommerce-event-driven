# Branching Strategy

## Branch Structure

```
main              ← production-ready, protected
  └── develop     ← integration branch
       ├── feature/infra-sns-sqs
       ├── feature/lambda-order-processor
       ├── feature/monitoring-alarms
       └── feature/demo-script
```

## Rules

### `main`
- Always deployable
- Merges only from `develop` via Pull Request
- Requires passing CI (terraform validate + plan + lambda tests)
- Tagged with semantic versions for releases (e.g., `v1.0.0`)

### `develop`
- Integration branch for all features
- Merges from feature branches via Pull Request
- Deploys to `dev` environment automatically

### `feature/*`
- Created from `develop`
- Naming: `feature/<scope>-<description>` (e.g., `feature/infra-sns-sqs`)
- Short-lived: merge back to `develop` when ready
- One concern per branch

### `hotfix/*`
- Created from `main` for urgent production fixes
- Merged to both `main` and `develop`

## Workflow

```
1. Create feature branch from develop
   git checkout develop && git pull
   git checkout -b feature/infra-sns-sqs

2. Work on the feature, commit often
   git add -A && git commit -m "Add SNS topic module"

3. Push and create PR to develop
   git push -u origin feature/infra-sns-sqs
   gh pr create --base develop

4. After review and CI passes, merge to develop

5. When develop is stable, PR from develop → main
   gh pr create --base main --head develop

6. Tag the release on main
   git tag -a v1.0.0 -m "Initial platform release"
   git push origin v1.0.0
```

## Commit Convention

```
<type>: <short description>

Types:
  feat:     New feature or infrastructure
  fix:      Bug fix
  docs:     Documentation only
  refactor: Code restructuring
  test:     Adding or updating tests
  ci:       CI/CD pipeline changes
  chore:    Maintenance tasks
```

Examples:
```
feat: add SQS module with DLQ support
fix: correct Lambda timeout for order processor
docs: add ADR for Standard vs FIFO queues
ci: add terraform plan to PR workflow
```
