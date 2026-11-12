# GPT-5.4 Drift / Policy Evaluation

## Purpose

This note summarizes whether the current AZ-305 lab code matches the intended operating model for Azure Policy drift, and what changes would make the workflow clearer and safer for a training-lab audience.

---

## Short Answer

The current codebase is **mostly aligned** with the right technical model, but the **user experience and documentation are not fully aligned** with it yet.

The good news is that the Terraform modules already do the most important thing correctly: they generally declare the **policy-enforced steady state directly** instead of trying to fight Azure Policy after deployment.

The main gap is not the Terraform itself. The main gap is the **workflow around it**:

- the repo currently leans on subscription profiling as a major part of the deployment model
- the docs do not explain that in simple learner-friendly language
- the quick-start path does not consistently guide users through policy compatibility detection first

For an **Azure architecture training lab**, the right model is:

1. Keep the profiler.
2. Make it a **plain-English compatibility check** for learners.
3. Use normal `terraform plan` / `terraform apply` / later-plan drift detection as the day-to-day loop.
4. Reserve deeper probing language and platform-contract ideas for internal design notes, not front-door learner docs.

---

## What the Current Code Gets Right

### 1. Semantic policy is modeled directly in Terraform

This is the strongest part of the current implementation.

Representative examples:

- `modules/03-keyvault/main.tf`
  - `public_network_access_enabled = false`
- `modules/06-storage/main.tf`
  - `public_network_access_enabled = false`
  - `allow_nested_items_to_be_public = false`
- several modules set auth/network/security options directly to the values Azure Policy is enforcing

Why this is good:

- it avoids endless “fix drift, rerun, drift again” loops
- it treats Azure Policy as part of the actual platform behavior
- it keeps Terraform aligned with the state Azure will really allow

### 2. `ignore_changes` is mostly being used for non-semantic noise

Examples:

- `tags["rg-class"]`
- `enabled_metric`
- `ip_tags`

Why this is good:

- these are examples of representational or platform-managed noise
- using `ignore_changes` there avoids unnecessary churn without hiding meaningful security or networking differences

### 3. The repository already has a fallback discovery mechanism

`az305-lab/prerequisites/profile-subscription.sh` is doing useful work:

- detecting SKU availability
- detecting regional service restrictions
- detecting policy-shaped behavior like storage auth and public access settings
- generating `modules/subscription-profile.auto.tfvars`

Why this is good:

- it makes the lab more portable across different Azure subscription types
- it reduces trial-and-error for learners
- it is especially useful because this repo has already encountered real subscription differences

---

## Where the Current Code Does Not Fully Match the Best Workflow

### 1. The profiler is effectively a primary control path, not just a helper

Technically, that is understandable. But conceptually it makes the repo feel like:

> “Deploying this lab requires policy discovery as a built-in mystery step.”

That is a problem for a training audience.

For learners, the workflow should feel more like:

> “Run this compatibility check so the lab can choose settings your subscription supports.”

That is the same behavior, but much clearer.

### 2. The README quick start does not reflect the policy-aware workflow

The current `README.md` quick start goes straight from prerequisites into manual module deployment.

That creates a gap:

- the repo contains a subscription profiler
- the lessons say policy and drift matter
- but the learner-facing quick start does not clearly say when or why to run the profiler

Result: users can miss the compatibility step and then hit confusing drift or deployment failures later.

### 3. The deployment scripts do not visibly enforce or validate the profile workflow

`scripts/deploy-module.sh` and `scripts/deploy-all.sh` deploy modules, but they do not clearly:

- check whether `subscription-profile.auto.tfvars` exists
- explain whether it is required, optional, or stale
- warn if the current subscription differs from the one the profile was generated for

That means the repo has important compatibility logic, but the actual deploy path does not strongly guide the user into using it correctly.

### 4. There is a small documentation mismatch in the generated profile

The generated `subscription-profile.auto.tfvars` says:

- SQL/App Service regions: `ARM what-if (dry-run, no resources created)`

But `profile-subscription.sh` actually performs create attempts for those checks.

Why this matters:

- it creates confusion about how detection works
- it weakens trust in the tool’s explanation
- it matters more here because the whole point is to make policy behavior easier to understand

---

## Recommended Changes

## Recommendation 1: Reframe the profiler as a learner-friendly compatibility check

### Suggested change

In learner-facing docs, describe `profile-subscription.sh` as:

> “A subscription compatibility check that detects which Azure features, regions, and security defaults your subscription supports, then writes safe Terraform defaults.”

Avoid terms like:

- platform contract
- landing zone contract
- second controller

in the main learner workflow docs.

Keep those ideas for internal notes, lessons learned, or advanced documentation.

### Reason

The current language risks requiring the learner to already understand enterprise platform concepts.

For an AZ-305 training lab, the user should only need to understand:

- Azure subscriptions differ
- policies may change what can be deployed
- this script checks and adapts to those differences

That is enough.

---

## Recommendation 2: Update the README quick start to include the profiler explicitly

### Suggested change

Change the quick start flow so it becomes:

1. Run `./prerequisites/check-prerequisites.sh`
2. Run `./prerequisites/profile-subscription.sh`
3. Deploy modules

Also add one short explanation line such as:

> “This step checks your subscription for policy restrictions and region/service availability so the lab can choose compatible defaults.”

### Reason

Right now the repo contains important policy compatibility logic, but the top-level onboarding flow does not consistently surface it.

If the lab depends on the profile for smooth deployment, the quick start should make that obvious.

---

## Recommendation 3: Add lightweight deploy-time checks for profile presence and staleness

### Suggested change

Before `deploy-module.sh` or `deploy-all.sh` runs Terraform, add checks like:

- does `modules/subscription-profile.auto.tfvars` exist?
- if not, print a clear message recommending `./prerequisites/profile-subscription.sh`
- optionally compare the current Azure subscription ID to the subscription noted in the generated profile

This does **not** need to hard-block deployment unless you want it to.

A warning may be enough, for example:

> “No subscription profile found. Deployment may fail if your subscription has policy or quota restrictions. Run `./prerequisites/profile-subscription.sh` first.”

### Reason

This makes the repository safer without making it feel over-engineered.

It also matches the practical reality of this lab: compatibility detection exists because subscription differences are real and important.

---

## Recommendation 4: Keep “deploy, detect drift later, then adapt” as the normal operating loop

### Suggested change

Document the normal mental model like this:

- run the compatibility check once up front
- deploy normally
- use future `terraform plan` runs to detect drift or platform changes
- if drift appears because the subscription behavior changed, update the configuration or rerun the compatibility check

### Reason

This is cleaner than treating canary probing as the everyday operating model.

It also matches your intuition:

- policy is usually fairly stable
- most daily work should not revolve around probing for hidden behavior
- later drift detection is a reasonable steady-state control for most environments

The profiler is still useful, but it should feel like:

- an onboarding step
- a re-check when the environment changes

not a constant mystery-box control loop

---

## Recommendation 5: Fix the profile output documentation mismatch

### Suggested change

Update the comments generated by `profile-subscription.sh` so they accurately describe the detection method being used.

For example, if SQL and App Service availability are checked with create attempts, the generated comments should say that directly.

### Reason

This is a small but worthwhile fix:

- it reduces confusion
- it improves trust in the profiler
- it keeps the repo’s educational story accurate

---

## Recommendation 6: Consider exposing more policy-shaped settings through variables

### Suggested change

Where semantic settings are currently hardcoded because the observed subscription enforces them, consider whether some of them should be fed from the generated profile or a clearer top-level variable pattern.

Examples include settings related to:

- public network access
- shared key access
- local auth enablement

This does **not** mean making the lab overly abstract.
It means making it easier to say:

> “These values come from subscription compatibility detection.”

instead of:

> “These are hardcoded because that happened to be true in our test subscription.”

### Reason

This better separates:

- lab logic
- subscription compatibility

It also makes the repo easier to explain and maintain if you later test against a second subscription type.

---

## Recommendation 7: Keep the advanced policy theory, but move it to the right layer

### Suggested change

Keep Lesson 15 and the deeper “second controller” framing, but treat it as:

- maintainer guidance
- architectural reasoning
- advanced explanation for why the repo is built this way

Do not make it the main wording in the learner onboarding flow.

### Reason

The theory is sound and useful.

The problem is not the theory itself. The problem is putting enterprise-platform vocabulary in front of users who are still learning Azure architecture basics.

That information belongs in:

- lessons learned
- maintainer notes
- advanced troubleshooting docs

not as a front-door prerequisite concept

---

## Bottom-Line Assessment

If the question is:

> “Does the current code match the tiered model?”

the answer is:

**Mostly yes technically, but not yet clearly in workflow and documentation.**

### Technically

Yes, because:

- semantic policy is largely modeled directly
- non-semantic drift is mostly handled appropriately
- the profiler exists as a practical compatibility layer

### Operationally / UX-wise

Not fully, because:

- the profiler is not presented clearly enough as a learner tool
- quick start does not consistently route through it
- deploy scripts do not strongly reinforce it
- some wording still reflects an internal enterprise framing rather than a training-lab framing

---

## Best Fit for This Repo

For this AZ-305 lab, the best model is:

1. **Learner-facing workflow**
   - prerequisites check
   - subscription compatibility check
   - deploy

2. **Normal ongoing workflow**
   - deploy normally
   - detect unexpected drift on later `terraform plan`
   - adapt only when needed

3. **Maintainer mental model**
   - Azure Policy can behave like a second controller
   - semantic policy must be modeled directly
   - the profiler exists because subscriptions differ and learner environments are unpredictable

That gives you the right balance of:

- correctness
- clarity
- portability
- lower cognitive load for learners

