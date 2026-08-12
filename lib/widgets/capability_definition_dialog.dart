import 'package:flutter/material.dart';

import '../models/dimension.dart';
import '../theme/dashboard_theme.dart';

void showCapabilityDefinitionDialog(
  BuildContext context,
  Dimension dimension,
) {
  final color = DashboardTheme.parseHex(dimension.color);

  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${dimension.id}. ${dimension.name}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Definition',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: DashboardTheme.muted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            dimension.descriptor,
            style: const TextStyle(
              fontSize: 13,
              height: 1.45,
              color: DashboardTheme.body,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}
