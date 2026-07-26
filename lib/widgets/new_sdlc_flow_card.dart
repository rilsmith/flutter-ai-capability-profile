import 'package:flutter/material.dart';

import '../theme/dashboard_theme.dart';

class NewSDLCFlowCard extends StatelessWidget {
  const NewSDLCFlowCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      decoration: DashboardTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'The New Agentic SDLC',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: DashboardTheme.heading,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'In an agentic workflow, the harness runs through every phase. '
            'The developer\'s role shifts from writing code to configuring '
            'the system that produces code. Each phase engages different parts of the harness.',
            style: TextStyle(fontSize: 13, color: DashboardTheme.muted, height: 1.5),
          ),
          const SizedBox(height: 20),
          _buildHarnessLayer(),
          const SizedBox(height: 20),
          _buildPhaseCard(
            '1',
            'Requirements, Planning & Architecture',
            'Configuring the Harness',
            'Define instructions, rule files (AGENTS.md), tools, APIs, and architectural guardrails.',
            'Conductor',
            const Color(0xFF2563EB),
            Icons.settings,
          ),
          const SizedBox(height: 12),
          _buildPhaseCard(
            '2',
            'Implementation',
            'Running the Harness',
            'Agents generate code within sandboxed environments using the tools and context provided by the harness.',
            'Orchestrator',
            const Color(0xFF0D9488),
            Icons.code,
          ),
          const SizedBox(height: 12),
          _buildPhaseCard(
            '3',
            'Testing & QA',
            'The Feedback Loop',
            'The harness captures test output, routes failures back to the agent, and iterates autonomously.',
            'Orchestrator',
            const Color(0xFFCA8A04),
            Icons.loop,
          ),
          const SizedBox(height: 12),
          _buildPhaseCard(
            '4',
            'Code Review, Deployment & Maintenance',
            'Observing the Harness',
            'Deterministic hooks block violations, observability traces agent decisions, humans review architecture.',
            'Conductor / Orchestrator',
            const Color(0xFF7C3AED),
            Icons.monitor_heart,
          ),
          const SizedBox(height: 20),
          _buildLegend(),
        ],
      ),
    );
  }

  Widget _buildHarnessLayer() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: DashboardTheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: DashboardTheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.foundation, size: 20, color: DashboardTheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'The Harness — Agent = Model + Harness',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: DashboardTheme.primary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Instructions & Rule Files · Tools · Sandboxes · Orchestration Logic · Guardrails / Hooks · Observability',
                  style: TextStyle(fontSize: 11, color: DashboardTheme.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhaseCard(
    String number,
    String phase,
    String action,
    String description,
    String mode,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    number,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  phase,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  action,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(icon, size: 16, color: color.withValues(alpha: 0.7)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: DashboardTheme.body,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                mode.contains('Orchestrator')
                    ? Icons.swap_horiz
                    : Icons.radio_button_checked,
                size: 14,
                color: DashboardTheme.muted,
              ),
              const SizedBox(width: 6),
              Text(
                'Developer mode: $mode',
                style: const TextStyle(
                  fontSize: 11,
                  color: DashboardTheme.muted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: DashboardTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Key Insight',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: DashboardTheme.heading,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'The transition from vibe coding to agentic engineering is not about the tools — '
            'it\'s about how deliberately you configure and apply the harness. Most agent failures, '
            'examined honestly, are configuration failures: a missing tool, a vague rule, an absent guardrail.',
            style: TextStyle(fontSize: 12, color: DashboardTheme.muted, height: 1.55),
          ),
        ],
      ),
    );
  }
}