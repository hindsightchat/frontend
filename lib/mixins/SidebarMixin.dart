import 'package:flutter/material.dart';
import 'package:hindsightchat/helpers/isMobile.dart';
import 'package:hindsightchat/providers/MobileNavigationProvider.dart';
import 'package:hindsightchat/providers/SidebarProvider.dart';
import 'package:provider/provider.dart';

/// Mixin for pages that need to set custom sidebar content.
///
/// The sidebar builder is called with the sidebar's context, so you can
/// use context.watch<Provider>() and the sidebar will rebuild when
/// that provider changes.
///
/// Usage:
/// ```dart
/// class MyPage extends StatefulWidget {
///   @override
///   State<MyPage> createState() => _MyPageState();
/// }
///
/// class _MyPageState extends State<MyPage> with SidebarMixin {
///   @override
///   Widget buildSidebar(BuildContext context) {
///     final data = context.watch<DataProvider>();
///
///     return ListView(
///       children: [
///         for (final friend in data.friends)
///           ListTile(
///             title: Text(friend.user.username),
///             onTap: () => openMobilePage(
///               context,
///               (ctx) => FriendDetailPage(friend: friend),
///             ),
///           ),
///       ],
///     );
///   }
///
///   @override
///   Widget build(BuildContext context) {
///     return Scaffold(body: Text('My Page Content'));
///   }
/// }
/// ```
mixin SidebarMixin<T extends StatefulWidget> on State<T> {
  /// Override this to provide custom sidebar content.
  /// Return null to use the default sidebar.
  ///
  /// The [context] parameter is from the sidebar widget, so you can
  /// use context.watch<Provider>() and the sidebar will automatically
  /// rebuild when that provider notifies listeners.
  Widget? buildSidebar(BuildContext context) => null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateSidebar();
    });
  }

  void _updateSidebar() {
    if (!mounted) return;
    context.read<SidebarProvider>().setSidebar(
      (sidebarContext) => buildSidebar(sidebarContext)!,
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}

/// Helper function to open a page on mobile (as a sliding sheet)
/// or do nothing on desktop (since the page is already visible).
///
/// Use this in sidebar item onTap handlers:
/// ```dart
/// ListTile(
///   title: Text('Friend'),
///   onTap: () => openMobilePage(context, (ctx) => FriendPage()),
/// )
/// ```
void openMobilePage(
  BuildContext context,
  Widget Function(BuildContext) builder,
) {
  if (isMobile(context)) {
    context.read<MobileNavigationProvider>().openPage(builder);
  }
  // On desktop, do nothing - the main content area already shows the page
}

/// Helper function to close the mobile page sheet
void closeMobilePage(BuildContext context) {
  if (isMobile(context)) {
    context.read<MobileNavigationProvider>().closePage();
  }
}

/// A reusable sidebar navigation item that handles both selection state
/// and mobile navigation automatically.
class SidebarNavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onSelect;
  final Widget Function(BuildContext)? mobilePageBuilder;

  const SidebarNavItem({
    super.key,
    required this.icon,
    required this.label,
    this.isSelected = false,
    required this.onSelect,
    this.mobilePageBuilder,
  });

  @override
  State<SidebarNavItem> createState() => _SidebarNavItemState();
}

class _SidebarNavItemState extends State<SidebarNavItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () {
          widget.onSelect();
          if (widget.mobilePageBuilder != null) {
            openMobilePage(context, widget.mobilePageBuilder!);
          }
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 2),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? const Color(0xFF404249)
                : (_isHovered ? const Color(0xFF35373C) : Colors.transparent),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              Icon(
                widget.icon,
                size: 20,
                color: widget.isSelected || _isHovered
                    ? const Color(0xFFDBDEE1)
                    : const Color(0xFF949BA4),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.label,
                  style: TextStyle(
                    color: widget.isSelected || _isHovered
                        ? const Color(0xFFDBDEE1)
                        : const Color(0xFF949BA4),
                    fontSize: 15,
                    fontWeight:
                        widget.isSelected ? FontWeight.w500 : FontWeight.normal,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A reusable sidebar section header
class SidebarSection extends StatelessWidget {
  final String title;
  final VoidCallback? onAddPressed;

  const SidebarSection({super.key, required this.title, this.onAddPressed});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title.toUpperCase(),
              style: const TextStyle(
                color: Color(0xFF949BA4),
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.24,
              ),
            ),
          ),
          if (onAddPressed != null)
            GestureDetector(
              onTap: onAddPressed,
              child: const Icon(Icons.add, size: 16, color: Color(0xFF949BA4)),
            ),
        ],
      ),
    );
  }
}
