import '../models/application_domain.dart';
import '../models/dashboard_data.dart';
import '../models/dimension.dart';
import '../models/maturity_level.dart';
import '../models/tier.dart';

const storageKey = 'ai-capability-dashboard-data';

const defaultDashboardData = DashboardData(
  title: 'Agentic Engineering Capability Profile',
  subtitle: 'Assessing 9 capability dimensions mapping the 8 levels of agentic engineering across the spectrum from vibe coding to software dark factories',
  intro:
      '''
      Many frameworks exist for evaluating maturity of agentic engineering, but they run into common maturity model pitfalls. While the concepts are useful for establishing a thought framework, these maturity models linearize AI skill progression by representing it as a sequential path of advancement when it is actually a multidimensional capability landscape. These tools attempt to capture the multidimensional nature of agentic engineering by assessing capability in 9 dimensions that map to the 8 levels of agentic engineering.

      The first five dimensions represent core competencies — the individual skills that make an engineer effective with AI, spanning Levels 1 through 5 (interaction, context engineering, compounding engineering, tool and capability engineering, and evaluation). The remaining four represent applied automation — how those skills compound into autonomous agentic workflows and ultimately software dark factories, spanning Levels 6 through 8 (harness engineering, automated feedback loops, orchestration and background agents, and autonomous agent systems).

      AI has not changed the core principles of effective software engineering. This is important because healthy teams consist of individuals with complementary skill sets. The most effective teams are those that have a balance of individuals with different capabilities, and that can collaborate effectively to solve problems. This is still true for agentic engineering.
      ''',
  dimensions: [
    Dimension(
      id: 1,
      name: 'Prompt & Interaction Design',
      score: 3.0,
      color: '#2563EB',
      descriptor: 'Tab complete, agent IDE, plan mode, conductor-mode, specifying intent',
    ),
    Dimension(
      id: 2,
      name: 'Context Engineering',
      score: 3.0,
      color: '#0D9488',
      descriptor: 'Static/dynamic context, rules files, the 6 context types, information density',
    ),
    Dimension(
      id: 3,
      name: 'Compounding Engineering',
      score: 3.0,
      color: '#16A34A',
      descriptor: 'Plan, delegate, assess, codify loop; persistent learning, codifying lessons',
    ),
    Dimension(
      id: 4,
      name: 'Tool & Capability Engineering',
      score: 3.0,
      color: '#CA8A04',
      descriptor: 'MCPs, skills, CLI tools, capability expansion, progressive disclosure',
    ),
    Dimension(
      id: 5,
      name: 'Evaluation & Verification',
      score: 3.0,
      color: '#EA580C',
      descriptor: 'Tests, evals, trajectory/output assessment, quality flywheel',
    ),
    Dimension(
      id: 6,
      name: 'Harness Engineering',
      score: 3.0,
      color: '#7C3AED',
      descriptor: 'Sandboxes, guardrails, hooks, observability, security boundaries',
    ),
    Dimension(
      id: 7,
      name: 'Automated Feedback Loops',
      score: 3.0,
      color: '#DB2777',
      descriptor: 'Backpressure, self-correction, CI quality gates, think-act-observe loop',
    ),
    Dimension(
      id: 8,
      name: 'Orchestration & Background Agents',
      score: 3.0,
      color: '#4F46E5',
      descriptor: 'Task decomposition, async delegation, multi-agent dispatch, orchestrator mode',
    ),
    Dimension(
      id: 9,
      name: 'Autonomous Agent Systems',
      score: 3.0,
      color: '#DC2626',
      descriptor: 'Factory model, spec-driven dev, agent teams, software dark factories',
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
      Higher scores (toward the outer ring) indicate stronger capability in that dimension. The first five dimensions (1–5) represent core competencies — the individual skills for working effectively with AI (Levels 1-5: tab complete through MCPs and skills). Dimensions 6–9 represent applied automation — how those skills compound into systems that build software at scale (Levels 6-8: harness engineering through autonomous agent teams).
      
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
