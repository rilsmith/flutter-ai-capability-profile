import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/dashboard_notifier.dart';
import 'theme/dashboard_theme.dart';
import 'utils/dashboard_pdf.dart';
import 'widgets/app_shell.dart';
import 'widgets/chart_scroll_lock.dart';
import 'widgets/dashboard_pdf_export_layer.dart';

class AiCapabilityDashboardApp extends StatelessWidget {
  const AiCapabilityDashboardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Capability Dashboard',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: DashboardTheme.background,
        colorScheme: ColorScheme.fromSeed(seedColor: DashboardTheme.primary),
      ),
      home: const _HomePage(),
    );
  }
}

class _HomePage extends StatefulWidget {
  const _HomePage();

  @override
  State<_HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<_HomePage> {
  final ValueNotifier<bool> _chartDragging = ValueNotifier(false);
  late final List<GlobalKey> _pdfSegmentKeys =
      List.generate(dashboardPdfSegmentCount, (_) => GlobalKey());
  bool _exportingPdf = false;
  double _exportProgress = 0;
  String _exportStatus = 'Preparing PDF…';

  @override
  void dispose() {
    _chartDragging.dispose();
    super.dispose();
  }

  Future<void> _exportPdf() async {
    setState(() {
      _exportingPdf = true;
      _exportProgress = 0;
      _exportStatus = 'Rendering dashboard…';
    });
    await WidgetsBinding.instance.endOfFrame;

    try {
      await exportDashboardPdf(
        _pdfSegmentKeys,
        onProgress: (progress, message) {
          if (mounted) {
            setState(() {
              _exportProgress = progress.clamp(0.0, 1.0);
              _exportStatus = message;
            });
          }
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PDF downloaded.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF export failed: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _exportingPdf = false);
      }
    }
  }

  Widget _exportingScaffold() {
    return Scaffold(
      backgroundColor: DashboardTheme.background,
      body: Stack(
        clipBehavior: Clip.none,
        children: [
          // Top-left in viewport (web black at left: -20000); avoid full-screen scroll paint.
          Positioned(
            left: 0,
            top: 0,
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.01,
                child: DashboardPdfExportLayer(
                  segmentKeys: _pdfSegmentKeys,
                ),
              ),
            ),
          ),
          const ModalBarrier(color: Color(0x66000000)),
          Center(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                child: SizedBox(
                  width: 300,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      LinearProgressIndicator(
                        value: _exportProgress > 0 ? _exportProgress : null,
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _exportStatus,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${(_exportProgress * 100).round()}%',
                        style: const TextStyle(
                          fontSize: 12,
                          color: DashboardTheme.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dashboardScaffold() {
    return Scaffold(
      body: ChartScrollLock(
        dragging: _chartDragging,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return ValueListenableBuilder<bool>(
              valueListenable: _chartDragging,
              builder: (context, chartDragging, child) {
                return SingleChildScrollView(
                  physics: chartDragging
                      ? const NeverScrollableScrollPhysics()
                      : const ClampingScrollPhysics(),
                  child: child,
                );
              },
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: AppShell(onExportPdf: _exportPdf),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<DashboardNotifier>();

    if (!notifier.initialized) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 20),
              Text('Initializing Dashboard...'),
            ],
          ),
        ),
      );
    }

    if (_exportingPdf) {
      return _exportingScaffold();
    }

    return _dashboardScaffold();
  }
}
