import 'package:flutter/material.dart';

import '../utils/dashboard_pdf.dart';
import 'app_shell.dart';

/// Dashboard layout used only while generating a PDF snapshot (rendered on-screen).
class DashboardPdfExportLayer extends StatelessWidget {
  const DashboardPdfExportLayer({
    super.key,
    required this.segmentKeys,
  });

  final List<GlobalKey> segmentKeys;

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQueryData(
        size: Size(dashboardPdfExportWidth, MediaQuery.sizeOf(context).height),
        devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
        padding: EdgeInsets.zero,
        viewPadding: EdgeInsets.zero,
        textScaler: MediaQuery.textScalerOf(context),
      ),
      child: ColoredBox(
        color: Colors.white,
        child: SizedBox(
          width: dashboardPdfExportWidth,
          child: AppShell(
            forPdfExport: true,
            pdfSegmentKeys: segmentKeys,
          ),
        ),
      ),
    );
  }
}
