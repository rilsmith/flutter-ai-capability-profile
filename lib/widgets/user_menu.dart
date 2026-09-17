import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_notifier.dart';
import '../theme/dashboard_theme.dart';
import '../utils/impersonation.dart';

/// Header user menu showing avatar, name, LDAP-derived manager/department,
/// and a Sign out option. Replaces the previous inline user bar.
class UserMenu extends StatelessWidget {
  const UserMenu({super.key});

  String _initials(String name) {
    if (name.trim().isEmpty) return '?';
    return name.trim()[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();
    final user = auth.user;
    if (user == null) return const SizedBox.shrink();

    final displayName = user.name.trim().isNotEmpty ? user.name : user.login;
    final ldap = auth.ldapInfo;
    final managerValue = (ldap != null && ldap.manager.isNotEmpty)
        ? ldap.manager
        : 'unavailable';
    final departmentValue = (ldap != null && ldap.departmentNumber.isNotEmpty)
        ? ldap.departmentNumber
        : 'unavailable';
    final hasAvatar = user.avatarUrl.isNotEmpty;

    return PopupMenuButton<void>(
      tooltip: 'User menu',
      offset: const Offset(0, 40),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: DashboardTheme.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: DashboardTheme.cardBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: DashboardTheme.primaryLight,
              backgroundImage: hasAvatar ? NetworkImage(user.avatarUrl) : null,
              child: !hasAvatar
                  ? Text(
                      _initials(displayName),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: DashboardTheme.primary,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                displayName,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Impersonation.active
                      ? DashboardTheme.primary
                      : DashboardTheme.body,
                ),
              ),
            ),
            if (Impersonation.active) ...[
              const SizedBox(width: 4),
              Text(
                'as ${Impersonation.uid}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: DashboardTheme.primary,
                ),
              ),
            ],
            const SizedBox(width: 4),
            const Icon(
              Icons.arrow_drop_down,
              size: 18,
              color: DashboardTheme.muted,
            ),
          ],
        ),
      ),
      itemBuilder: (context) => [
        PopupMenuItem<void>(
          enabled: false,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 220, maxWidth: 320),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: DashboardTheme.primaryLight,
                      backgroundImage:
                          hasAvatar ? NetworkImage(user.avatarUrl) : null,
                      child: !hasAvatar
                          ? Text(
                              _initials(displayName),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: DashboardTheme.primary,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: DashboardTheme.heading,
                            ),
                          ),
                          if (user.email.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              user.email,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: DashboardTheme.muted,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: DashboardTheme.cardBorder),
                const SizedBox(height: 12),
                _InfoRow(
                  label: 'Manager',
                  value: managerValue,
                  isUnavailable: managerValue == 'unavailable',
                ),
                const SizedBox(height: 6),
                _InfoRow(
                  label: 'Department',
                  value: departmentValue,
                  isUnavailable: departmentValue == 'unavailable',
                ),
              ],
            ),
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<void>(
          onTap: () => auth.logout(),
          child: const Row(
            children: [
              Icon(Icons.logout, size: 18, color: DashboardTheme.muted),
              SizedBox(width: 10),
              Text(
                'Sign out',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: DashboardTheme.body,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.isUnavailable = false,
  });

  final String label;
  final String value;
  final bool isUnavailable;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: DashboardTheme.muted,
          ),
        ),
        const Text(
          ': ',
          style: TextStyle(
            fontSize: 12,
            color: DashboardTheme.muted,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isUnavailable ? FontWeight.w500 : FontWeight.w600,
              color: isUnavailable ? DashboardTheme.muted : DashboardTheme.body,
              fontStyle: isUnavailable ? FontStyle.italic : FontStyle.normal,
            ),
          ),
        ),
      ],
    );
  }
}
