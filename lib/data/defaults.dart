import '../models/application_domain.dart';
import '../models/dashboard_data.dart';
import '../models/dimension.dart';
import '../models/maturity_level.dart';
import '../models/tier.dart';

const storageKey = 'ai-capability-dashboard-data';

const defaultDashboardData = DashboardData(
  title: 'Agentic Engineering Capability Profile',
  subtitle: 'Assessing 5 capability dimensions mapping the progression from individual AI interaction to autonomous agentic automation',
  intro:
      '''
      Many frameworks exist for evaluating maturity of agentic engineering, but they run into common maturity model pitfalls. While the concepts are useful for establishing a thought framework, these maturity models linearize AI skill progression by representing it as a sequential path of advancement when it is actually a multidimensional capability landscape. These tools attempt to capture the multidimensional nature of agentic engineering by assessing capability in 5 dimensions that map to the progression from individual interaction to autonomous agentic automation.

      The five dimensions form a coherent capability stack. Prompt Engineering and Context Engineering are the foundation — how you specify intent and shape the information agents work with. Tool / Skill Engineering extends that foundation into reusable capabilities and interfaces. Harness Engineering builds assurance, guardrails, and observability around those capabilities. Agentic Automation is the apex — autonomous workflows and systems that compound the preceding skills into self-directed engineering.

      AI has not changed the core principles of effective software engineering. This is important because healthy teams consist of individuals with complementary skill sets. The most effective teams are those that have a balance of individuals with different capabilities, and that can collaborate effectively to solve problems. This is still true for agentic engineering.
      ''',
  dimensions: [
    Dimension(
      id: 1,
      name: 'Prompt Engineering',
      score: 3.0,
      color: '#2563EB',
      descriptor: 'Craft effective instructions, examples, constraints, and output formats.',
    ),
    Dimension(
      id: 2,
      name: 'Context Engineering',
      score: 3.0,
      color: '#0D9488',
      descriptor: 'Manage what the agent knows: memory, AGENTS.md, retrieval, relevant files, and token budgets.',
    ),
    Dimension(
      id: 3,
      name: 'Tool / Skill Engineering',
      score: 3.0,
      color: '#CA8A04',
      descriptor: 'Extend what the agent can do with tools, APIs, MCP servers, and reusable skills.',
    ),
    Dimension(
      id: 4,
      name: 'Harness Engineering',
      score: 3.0,
      color: '#7C3AED',
      descriptor: 'Make agent execution safe and reliable with cost caps, permission tiers, sandboxes, network/execution isolation, approvals, and validation.',
    ),
    Dimension(
      id: 5,
      name: 'Agentic Automation',
      score: 3.0,
      color: '#DC2626',
      descriptor: 'Run trusted agent workflows automatically through schedules, events, monitoring, and human escalation.',
    ),
  ],
  applicationDomains: [
    ApplicationDomain(
      id: 1,
      name: 'Discovery & Research',
      shortName: 'Discovery',
      applicability: DomainApplicability.inScope,
      involvement: DomainInvolvement.occasional,
      value: DomainSignal.moderate,
      confidence: DomainSignal.moderate,
      capabilityIds: [],
    ),
    ApplicationDomain(
      id: 2,
      name: 'Requirements & Planning',
      shortName: 'Requirements',
      applicability: DomainApplicability.inScope,
      involvement: DomainInvolvement.occasional,
      value: DomainSignal.moderate,
      confidence: DomainSignal.moderate,
      capabilityIds: [],
    ),
    ApplicationDomain(
      id: 3,
      name: 'Architecture & Design',
      shortName: 'Architecture',
      applicability: DomainApplicability.inScope,
      involvement: DomainInvolvement.occasional,
      value: DomainSignal.moderate,
      confidence: DomainSignal.moderate,
      capabilityIds: [],
    ),
    ApplicationDomain(
      id: 4,
      name: 'Implementation',
      shortName: 'Implementation',
      applicability: DomainApplicability.inScope,
      involvement: DomainInvolvement.occasional,
      value: DomainSignal.moderate,
      confidence: DomainSignal.moderate,
      capabilityIds: [],
    ),
    ApplicationDomain(
      id: 5,
      name: 'Testing & Validation',
      shortName: 'Testing',
      applicability: DomainApplicability.inScope,
      involvement: DomainInvolvement.occasional,
      value: DomainSignal.moderate,
      confidence: DomainSignal.moderate,
      capabilityIds: [],
    ),
    ApplicationDomain(
      id: 6,
      name: 'Deployment & Release',
      shortName: 'Deployment',
      applicability: DomainApplicability.inScope,
      involvement: DomainInvolvement.occasional,
      value: DomainSignal.moderate,
      confidence: DomainSignal.moderate,
      capabilityIds: [],
    ),
    ApplicationDomain(
      id: 7,
      name: 'Operations & Incident Response',
      shortName: 'Operations',
      applicability: DomainApplicability.inScope,
      involvement: DomainInvolvement.occasional,
      value: DomainSignal.moderate,
      confidence: DomainSignal.moderate,
      capabilityIds: [],
    ),
    ApplicationDomain(
      id: 8,
      name: 'Documentation & Knowledge Sharing',
      shortName: 'Documentation',
      applicability: DomainApplicability.inScope,
      involvement: DomainInvolvement.occasional,
      value: DomainSignal.moderate,
      confidence: DomainSignal.moderate,
      capabilityIds: [],
    ),
    ApplicationDomain(
      id: 9,
      name: 'Coordination',
      shortName: 'Coordination',
      applicability: DomainApplicability.inScope,
      involvement: DomainInvolvement.occasional,
      value: DomainSignal.moderate,
      confidence: DomainSignal.moderate,
      capabilityIds: [],
    ),
  ],
  maturityScale: [
    MaturityLevel(
      level: 1,
      label: 'Ad Hoc',
      color: '#DC2626',
      description: 'Minimal or no capability; done inconsistently',
    ),
    MaturityLevel(
      level: 2,
      label: 'Emerging',
      color: '#EA580C',
      description: 'Early practices; limited consistency or adoption',
    ),
    MaturityLevel(
      level: 3,
      label: 'Developing',
      color: '#CA8A04',
      description: 'Defined practices; used by some of the team',
    ),
    MaturityLevel(
      level: 4,
      label: 'Advanced',
      color: '#16A34A',
      description: 'Consistent, effective practices; widely adopted',
    ),
    MaturityLevel(
      level: 5,
      label: 'Leading',
      color: '#15803D',
      description: 'Systemic, measurable impact; continuously improving',
    ),
  ],
  howToRead:
      '''
      Higher scores (toward the outer ring) indicate stronger capability in that dimension. The five dimensions form a progression from individual interaction to autonomous systems: Prompt Engineering (specifying intent), Context Engineering (shaping information), Tool / Skill Engineering (reusable capabilities), Harness Engineering (assurance and guardrails), and Agentic Automation (autonomous workflows and agent teams).
      
      To illustrate the importance of individuals with complementary capabilities, the capability scores are translated into a "class" just like how an effective RPG party might have a mix of characters with different abilities.
      ''',
  applicationHowToRead:
      'Coding (i.e. Implementation) is the most common domain for agent use, but it\'s not the only one. This helps visualize how well you use agents in each domain of the software development development lifecycle. Click a lifecycle bar to cycle agent use (Never → Occasional → Regular).',
  applicationMatrixHowToRead:
      'This matrix helps break down each capability across each domain. Click a cell to link or unlink a capability in that domain. Involvement (lifecycle strip) and capability links are independent — both contribute to your profile. Colored cells show where a capability manifests; empty cells are not linked. N/A domains are read-only (set in Edit panel).',
  tiers: TierGroup(
    high: Tier(label: 'High (4.0–5.0)', color: '#16A34A', min: 4.0),
    medium: Tier(label: 'Medium (2.5–3.9)', color: '#CA8A04', min: 2.5),
    low: Tier(label: 'Low (1.0–2.4)', color: '#DC2626', min: 1.0),
  ),
  maxScore: 5,
);
