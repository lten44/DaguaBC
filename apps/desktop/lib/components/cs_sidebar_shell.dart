// lib/components/cs_sidebar_shell.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:bhe_l10n/bhe_l10n.dart';

import '../theme/app_colors.dart';
import '../theme/tokens.dart';
import '../features/about/about_dialog.dart';
import '../features/settings/settings_dialog.dart';

/// 桌面侧栏:`≥ md(900)` 时显示；展开/收缩由用户控制，宽度不足时自动使用折叠态。
///
/// 4 CsSidebarItem + 底部设置与关于。导航通过
/// `shell.goBranch(index)` 切换 StatefulNavigationShell 的当前 branch。
class CsSidebarShell extends StatelessWidget {
  const CsSidebarShell({
    required this.shell,
    required this.extended,
    super.key,
  });

  final StatefulNavigationShell shell;
  final bool extended;
  static const expandedWidth = 224.0;
  static const collapsedWidth = 76.0;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l10n = Localizations.of<BheLocalizations>(context, BheLocalizations);
    return Container(
      width: extended ? expandedWidth : collapsedWidth,
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(right: BorderSide(color: c.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const SizedBox(height: 12),
          _NavItem(
            shell: shell,
            index: 0,
            label: l10n?.navProject ?? '项目',
            icon: LucideIcons.home,
            extended: extended,
          ),
          _NavItem(
            shell: shell,
            index: 1,
            label: l10n?.navImport ?? '导入',
            icon: LucideIcons.upload,
            extended: extended,
          ),
          _NavItem(
            shell: shell,
            index: 2,
            label: l10n?.navReview ?? '审核',
            icon: LucideIcons.folderCheck,
            extended: extended,
          ),
          _NavItem(
            shell: shell,
            index: 3,
            label: l10n?.navExport ?? '导出',
            icon: LucideIcons.download,
            extended: extended,
          ),
          const Spacer(),
          _UtilityItem(
            label: '设置',
            icon: LucideIcons.settings,
            extended: extended,
            onTap: () => showDaguaSettingsDialog(context),
          ),
          _UtilityItem(
            label: l10n?.about ?? '关于',
            icon: LucideIcons.info,
            extended: extended,
            onTap: () => showCourtsideAboutDialog(context),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: extended ? 22 : 0, vertical: 8),
            child: Tooltip(
              key: const Key('local-processing-info'),
              message: context.bheText('视频在本机处理\n识别和导出均在这台电脑完成。'),
              child: Row(
                mainAxisAlignment: extended ? MainAxisAlignment.start : MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.shieldCheck, size: 14, color: c.textTertiary),
                  if (extended) ...[
                    const SizedBox(width: 10),
                    Flexible(child: Text(
                      context.bheText('视频在本机处理'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: c.textTertiary),
                    )),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: Spacing.md),
        ],
      ),
    );
  }
}

class _UtilityItem extends StatelessWidget {
  const _UtilityItem({
    required this.label,
    required this.icon,
    required this.extended,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool extended;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final child = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: extended ? 10 : 12,
        vertical: 1,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(CsRadius.sm),
          onTap: onTap,
          child: SizedBox(
            height: 34,
            child: Padding(
              padding: EdgeInsets.only(
                left: extended ? 12 : 0,
                right: extended ? 8 : 0,
              ),
              child: Row(
                mainAxisAlignment: extended
                    ? MainAxisAlignment.start
                    : MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 17, color: c.textTertiary),
                  if (extended) ...[
                    const SizedBox(width: Spacing.sm + 2),
                    Text(
                      label,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: c.textSecondary),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
    return extended ? child : Tooltip(message: label, child: child);
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.shell,
    required this.index,
    required this.label,
    required this.icon,
    required this.extended,
  });

  final StatefulNavigationShell shell;
  final int index;
  final String label;
  final IconData icon;
  final bool extended;

  @override
  Widget build(BuildContext context) {
    return CsSidebarItem(
      label: label,
      icon: icon,
      selected: shell.currentIndex == index,
      extended: extended,
      onTap: () => shell.goBranch(index),
    );
  }
}

/// 位于侧栏与主内容分界线上的展开 / 收起按钮。
class CsSidebarToggle extends StatelessWidget {
  const CsSidebarToggle({
    required this.extended,
    required this.onToggle,
    super.key,
  });

  final bool extended;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l10n = Localizations.of<BheLocalizations>(context, BheLocalizations);
    return Material(
      color: c.surface2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: c.borderStrong),
      ),
      child: IconButton(
        tooltip: extended
            ? (l10n?.collapseSidebar ?? '收缩侧栏')
            : (l10n?.expandSidebar ?? '展开侧栏'),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 32, height: 32),
        onPressed: onToggle,
        icon: Icon(
          extended ? LucideIcons.chevronLeft : LucideIcons.chevronRight,
          size: 20,
          color: c.textSecondary,
        ),
      ),
    );
  }
}

/// 单个侧栏项。
///
/// 选中态:局部橙色背景 + 文字 w600 + 图标橙色;
/// 未选中:textSecondary。折叠态(extended=false)只显示图标 + Tooltip(label)。
class CsSidebarItem extends StatelessWidget {
  const CsSidebarItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.extended,
    required this.onTap,
    this.selectedIcon,
    super.key,
  });

  final String label;
  final IconData icon;
  final IconData? selectedIcon;
  final bool selected;
  final bool extended;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final fg = selected ? c.orange : c.textSecondary;
    final iconData = selected ? (selectedIcon ?? icon) : icon;

    final inner = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: extended ? 10 : 10,
        vertical: extended ? 2 : 1,
      ),
      child: Material(
        color: selected ? c.orange.withValues(alpha: 0.10) : Colors.transparent,
        borderRadius: BorderRadius.circular(CsRadius.sm),
        child: InkWell(
          hoverColor: Colors.transparent,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          borderRadius: BorderRadius.circular(CsRadius.sm),
          onTap: onTap,
          child: SizedBox(
            height: 48,
            child: Padding(
              padding: EdgeInsets.only(
                left: extended ? 12 : 0,
                right: extended ? 8 : 0,
              ),
              child: Row(
                mainAxisAlignment: extended
                    ? MainAxisAlignment.start
                    : MainAxisAlignment.center,
                children: <Widget>[
                  Icon(iconData, size: 22, color: fg),
                  if (extended) ...<Widget>[
                    const SizedBox(width: 14),
                    Text(
                      label,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 16,
                        color: selected ? c.textPrimary : c.textSecondary,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
    return extended ? inner : Tooltip(message: label, child: inner);
  }
}
