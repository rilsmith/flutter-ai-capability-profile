/// Contextual help for the SDLC stage columns in the adoption matrices.
///
/// Keyed by the full [ApplicationDomain.name] from `lib/data/defaults.dart`.
/// Copy conventions: second person, activity verbs, at least one AI-specific
/// example per stage (this is an AI capability matrix), and a boundary note
/// for the most likely adjacent-stage mix-up.
class DomainHelp {
  const DomainHelp({
    required this.definition,
    required this.activities,
    required this.aiExamples,
    required this.boundary,
  });

  final String definition;
  final List<String> activities;
  final List<String> aiExamples;
  final String boundary;
}

const Map<String, DomainHelp> domainHelp = {
  'Discovery & Research': DomainHelp(
    definition: 'Understanding the problem before committing to a solution.',
    activities: [
      'Explore a codebase, service, or dataset to scope an idea',
      'Compare approaches, tools, or vendors',
      'Dig through docs, tickets, logs, or customer feedback for patterns',
    ],
    aiExamples: [
      '"Summarize this repo"',
      '"Compare option A vs B for our constraints"',
      '"Find themes in these support tickets"',
    ],
    boundary:
        'Writing user stories or sizing the work belongs in Requirements & Planning.',
  ),
  'Requirements & Planning': DomainHelp(
    definition: 'Turning an understood problem into a plan of work.',
    activities: [
      'Write or refine user stories and acceptance criteria',
      'Estimate effort and break epics into tickets',
      'Plan sprints and define done',
    ],
    aiExamples: [
      'Draft acceptance criteria from a spec',
      'Turn meeting notes into tickets',
      '"What edge cases does this requirement miss?"',
    ],
    boundary:
        'Deciding how it will be built (patterns, components) is Architecture & Design.',
  ),
  'Architecture & Design': DomainHelp(
    definition: 'Deciding how the solution works.',
    activities: [
      'Design interfaces or data models',
      'Pick patterns and libraries',
      'Write design docs or ADRs, review someone else\'s design',
    ],
    aiExamples: [
      '"Propose two designs with tradeoffs"',
      '"What failure modes does this design have?"',
      'Draft an ADR',
    ],
    boundary: 'Writing the actual code is Implementation.',
  ),
  'Implementation': DomainHelp(
    definition: 'Writing and reviewing production code.',
    activities: [
      'Write features or fixes with AI in the loop',
      'Refactor or write migrations',
      'Review PRs, configure or drive coding agents',
    ],
    aiExamples: [
      'Pair-programming with Copilot / Cursor',
      'Delegating a refactor to an agent',
      '"Explain this legacy code", AI-assisted code review',
    ],
    boundary:
        'Writing tests while coding counts here; designing test strategy and validating behavior is Testing & Validation.',
  ),
  'Testing & Validation': DomainHelp(
    definition: 'Proving the thing works and keeps working.',
    activities: [
      'Design test plans',
      'Write unit, integration, or e2e tests',
      'Triage regressions, validate output quality (evals, golden sets)',
    ],
    aiExamples: [
      'Generate test cases from a diff',
      'Build an eval harness',
      '"What edge cases haven\'t I tested?", flaky-test triage',
    ],
    boundary:
        'Getting code through pipelines is Deployment; responding to production failures is Operations.',
  ),
  'Deployment & Release': DomainHelp(
    definition: 'Getting code safely to production.',
    activities: [
      'Maintain CI/CD pipelines',
      'Write Dockerfiles and k8s manifests',
      'Plan rollouts and canaries, manage feature flags, write release notes',
    ],
    aiExamples: [
      '"Why is this pipeline failing?"',
      'Generate or fix GitHub Actions YAML',
      'Draft release notes from merged PRs',
    ],
    boundary: 'Keeping it healthy after release is Operations.',
  ),
  'Operations & Incident Response': DomainHelp(
    definition: 'Running and defending the system in production.',
    activities: [
      'On-call triage and incident response',
      'Build dashboards and alerts, analyze logs',
      'Write postmortems, tune performance',
    ],
    aiExamples: [
      '"Summarize these logs and hypothesize root causes"',
      'Draft an incident timeline or postmortem',
      'Correlate alerts',
    ],
    boundary:
        'Planned infrastructure work is Deployment or Implementation; this column is the unplanned, keep-the-lights-on side.',
  ),
  'Documentation & Knowledge Sharing': DomainHelp(
    definition: 'Making knowledge durable and findable.',
    activities: [
      'Write READMEs, wikis, runbooks, API docs',
      'Write onboarding guides',
      'Give team talks or demos',
    ],
    aiExamples: [
      'Draft docs from code or PR history',
      '"Generate API reference for this module"',
      'Distill a long thread into a wiki page',
    ],
    boundary:
        'Code comments and PR descriptions are Implementation hygiene; this column is durable, shared artifacts.',
  ),
  'Coordination': DomainHelp(
    definition: 'Keeping humans aligned and unblocked.',
    activities: [
      'Run standups and cross-team syncs',
      'Write status updates, manage stakeholders',
      'Track dependencies, escalate blockers',
    ],
    aiExamples: [
      'Draft status updates from ticket and commit activity',
      'Meeting agendas and summaries',
      '"Digest this 40-message thread"',
    ],
    boundary:
        'Writing tickets (the artifact) is Requirements & Planning; this column is the communication around keeping work moving.',
  ),
};
