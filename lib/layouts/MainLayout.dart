import 'package:flutter/material.dart';
import 'package:hindsightchat/components/Colours.dart';
import 'package:hindsightchat/helpers/isMobile.dart';
import 'package:hindsightchat/providers/AuthProvider.dart';
import 'package:hindsightchat/providers/DataProvider.dart';
import 'package:hindsightchat/providers/MobileNavigationProvider.dart';
import 'package:hindsightchat/providers/SidebarProvider.dart';
import 'package:hindsightchat/types/models.dart';
import 'package:provider/provider.dart';

class MainLayout extends StatefulWidget {
  final Widget child;

  const MainLayout({super.key, required this.child});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  @override
  Widget build(BuildContext context) {
    final mobile = isMobile(context);

    return Scaffold(
      body: Container(
        padding: EdgeInsets.only(top: mobile ? 0 : 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [DarkBackgroundColor, const Color.fromARGB(255, 0, 0, 0)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: mobile
            ? _MobileLayout(child: widget.child)
            : _DesktopLayout(child: widget.child),
      ),
    );
  }
}

/// Desktop layout with sidebars and main content
class _DesktopLayout extends StatelessWidget {
  final Widget child;

  const _DesktopLayout({required this.child});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Left section: Server sidebar + Content sidebar + User panel
        SizedBox(
          width: 72 + 300,
          child: Stack(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [const ServerSidebar(), const ContentSidebar()],
              ),
              const Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: UserPanel(),
              ),
            ],
          ),
        ),
        // Main content area
        Expanded(child: child),
      ],
    );
  }
}

/// Mobile layout with sidebar only + sliding page sheet
class _MobileLayout extends StatefulWidget {
  final Widget child;

  const _MobileLayout({required this.child});

  @override
  State<_MobileLayout> createState() => _MobileLayoutState();
}

class _MobileLayoutState extends State<_MobileLayout>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onHorizontalDragStart(DragStartDetails details) {
    _isDragging = true;
  }

  void _onHorizontalDragUpdate(
    DragUpdateDetails details,
    MobileNavigationProvider mobileNav,
  ) {
    final delta = details.primaryDelta ?? 0;
    final screenWidth = context.size?.width ?? 400;

    if (mobileNav.isPageOpen || mobileNav.pageBuilder != null) {
      // Page is open or being dragged - allow bidirectional dragging
      // Swipe right (delta > 0) closes, swipe left (delta < 0) opens
      final newValue = (_controller.value - delta / screenWidth).clamp(0.0, 1.0);
      _controller.value = newValue;
    } else if (mobileNav.hasLastPage && delta < 0) {
      // Page is closed and has a last page - start opening on left swipe
      mobileNav.reopenLastPage();
      _controller.value = (-delta / screenWidth).clamp(0.0, 1.0);
    }
  }

  void _onHorizontalDragEnd(
    DragEndDetails details,
    MobileNavigationProvider mobileNav,
  ) {
    _isDragging = false;
    final velocity = details.primaryVelocity ?? 0;

    if (mobileNav.isPageOpen || mobileNav.pageBuilder != null) {
      // Determine whether to open or close based on position and velocity
      if (_controller.value > 0.5 || velocity < -500) {
        // Open the page
        _controller.forward();
        if (!mobileNav.isPageOpen) {
          mobileNav.reopenLastPage();
        }
      } else {
        // Close the page
        _controller.reverse().then((_) {
          mobileNav.closePage();
          mobileNav.clearPage();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mobileNav = context.watch<MobileNavigationProvider>();

    // Animate based on page state (only if not dragging)
    if (!_isDragging) {
      if (mobileNav.isPageOpen && mobileNav.pageBuilder != null) {
        _controller.forward();
      } else if (!mobileNav.isPageOpen && _controller.value > 0) {
        _controller.reverse().then((_) {
          if (!mobileNav.isPageOpen) {
            mobileNav.clearPage();
          }
        });
      }
    }

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragStart: _onHorizontalDragStart,
      onHorizontalDragUpdate: (details) =>
          _onHorizontalDragUpdate(details, mobileNav),
      onHorizontalDragEnd: (details) =>
          _onHorizontalDragEnd(details, mobileNav),
      child: Stack(
        children: [
          // Sidebar takes full width on mobile
          Column(
            children: [
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const ServerSidebar(),
                    const Expanded(child: MobileContentSidebar()),
                  ],
                ),
              ),
              const MobileUserPanel(),
            ],
          ),
          // Edge swipe indicator (shows when there's a page to reopen)
          if (mobileNav.hasLastPage &&
              !mobileNav.isPageOpen &&
              mobileNav.pageBuilder == null)
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: Container(
                width: 4,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.transparent, Colors.white.withOpacity(0.1)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                ),
              ),
            ),
          // Sliding page sheet
          if (mobileNav.pageBuilder != null)
            SlideTransition(
              position: _slideAnimation,
              child: Container(
                color: DarkBackgroundColor,
                child: SafeArea(
                  child: Column(
                    children: [
                      Expanded(child: mobileNav.pageBuilder!(context)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Mobile-optimized content sidebar (full width)
class MobileContentSidebar extends StatelessWidget {
  const MobileContentSidebar({super.key});

  @override
  Widget build(BuildContext context) {
    final sidebarBuilder = context.watch<SidebarProvider>().sidebarBuilder;

    return Container(
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: MessageBorderColor, width: 1),
          top: BorderSide(color: MessageBorderColor, width: 1),
        ),
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(10)),
      ),
      child: Column(
        children: [
          // Search bar
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(width: 1)),
            ),
            child: GestureDetector(
              onTap: () {},
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1F22),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.search, size: 20, color: Color(0xFF949BA4)),
                    SizedBox(width: 8),
                    Text(
                      'Search',
                      style: TextStyle(color: Color(0xFF949BA4), fontSize: 15),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Sidebar content
          Expanded(
            child: sidebarBuilder != null
                ? (sidebarBuilder(context) ?? const _DefaultSidebarContent())
                : const _DefaultSidebarContent(),
          ),
        ],
      ),
    );
  }
}

/// Mobile user panel (simpler, full width)
class MobileUserPanel extends StatelessWidget {
  const MobileUserPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.user;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF232428),
        border: Border(top: BorderSide(color: MessageBorderColor, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Avatar
            Stack(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: const Color(0xFF5865F2),
                    image: const DecorationImage(
                      image: NetworkImage("https://github.com/DwifteJB.png"),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: const Color(0xFF23A559),
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(
                        color: const Color(0xFF232428),
                        width: 3,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            // Username
            Expanded(
              child: Text(
                user?.username ?? 'User',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Settings button
            IconButton(
              icon: const Icon(Icons.settings, color: Color(0xFFB5BAC1)),
              onPressed: () {},
            ),
          ],
        ),
      ),
    );
  }
}

/// Discord-style server sidebar with icons
class ServerSidebar extends StatefulWidget {
  const ServerSidebar({super.key});

  @override
  State<ServerSidebar> createState() => _ServerSidebarState();
}

class _ServerSidebarState extends State<ServerSidebar> {
  int _selectedIndex = 0;
  int _hoveredIndex = -1;

  @override
  Widget build(BuildContext context) {
    final dataProvider = context.watch<DataProvider>();
    final servers = dataProvider.servers;

    return Container(
      width: 72,
      child: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: servers.length + 2,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _ServerIconWidget(
                    isHome: true,
                    isSelected: _selectedIndex == 0,
                    isHovered: _hoveredIndex == 0,
                    onTap: () => setState(() => _selectedIndex = 0),
                    onHover: (h) => setState(() => _hoveredIndex = h ? 0 : -1),
                    showSeparator: true,
                  );
                } else if (index <= servers.length) {
                  final server = servers[index - 1];
                  final isSelected = _selectedIndex == index;
                  final isHovered = _hoveredIndex == index;

                  return _ServerIconWidget(
                    server: server,
                    isSelected: isSelected,
                    isHovered: isHovered,
                    onTap: () => setState(() => _selectedIndex = index),
                    onHover: (h) =>
                        setState(() => _hoveredIndex = h ? index : -1),
                  );
                } else {
                  return _AddServerButton(
                    isHovered: _hoveredIndex == index,
                    onHover: (h) =>
                        setState(() => _hoveredIndex = h ? index : -1),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ServerIconWidget extends StatelessWidget {
  final Server? server;
  final bool isHome;
  final bool isSelected;
  final bool isHovered;
  final VoidCallback onTap;
  final ValueChanged<bool> onHover;
  final bool showSeparator;

  const _ServerIconWidget({
    this.server,
    this.isHome = false,
    required this.isSelected,
    required this.isHovered,
    required this.onTap,
    required this.onHover,
    this.showSeparator = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: -8,
                top: 0,
                bottom: 0,
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 4,
                    height: isSelected ? 40 : (isHovered ? 20 : 0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
              MouseRegion(
                onEnter: (_) => onHover(true),
                onExit: (_) => onHover(false),
                child: GestureDetector(
                  onTap: onTap,
                  child: Tooltip(
                    message: isHome ? 'Direct Messages' : (server?.name ?? ''),
                    preferBelow: false,
                    verticalOffset: 0,
                    waitDuration: const Duration(milliseconds: 500),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(
                          isSelected || isHovered ? 16 : 24,
                        ),
                        image: (!isHome && server?.icon != null)
                            ? DecorationImage(
                                image: NetworkImage(server!.icon!),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: Center(
                        child: isHome
                            ? Image.asset(
                                'assets/hindsight.png',
                                width: 28,
                                height: 28,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.home,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              )
                            : (server?.icon == null
                                  ? Text(
                                      _getServerInitials(server?.name ?? ''),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                      ),
                                    )
                                  : null),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (showSeparator)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            height: 2,
            decoration: BoxDecoration(
              color: const Color(0xFF35363C),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
      ],
    );
  }

  String _getServerInitials(String name) {
    if (name.isEmpty) return '?';
    final words = name.split(' ');
    if (words.length >= 2) {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    }
    return name.substring(0, name.length.clamp(0, 2)).toUpperCase();
  }
}

class _AddServerButton extends StatelessWidget {
  final bool isHovered;
  final ValueChanged<bool> onHover;

  const _AddServerButton({required this.isHovered, required this.onHover});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: MouseRegion(
        onEnter: (_) => onHover(true),
        onExit: (_) => onHover(false),
        child: GestureDetector(
          onTap: () {},
          child: Tooltip(
            message: 'Add a Server',
            preferBelow: false,
            waitDuration: const Duration(milliseconds: 500),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isHovered
                    ? const Color(0xFF23A559)
                    : const Color(0xFF313338),
                borderRadius: BorderRadius.circular(isHovered ? 24 : 16),
              ),
              child: Icon(
                Icons.add,
                color: isHovered ? Colors.white : const Color(0xFF23A559),
                size: 24,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Desktop content sidebar
class ContentSidebar extends StatelessWidget {
  const ContentSidebar({super.key});

  @override
  Widget build(BuildContext context) {
    final sidebarBuilder = context.watch<SidebarProvider>().sidebarBuilder;

    return Container(
      width: 300,
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: MessageBorderColor, width: 1),
          top: BorderSide(color: MessageBorderColor, width: 1),
          right: BorderSide(color: MessageBorderColor, width: 1),
        ),
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(10)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(width: 1)),
            ),
            child: GestureDetector(
              onTap: () {},
              child: Container(
                height: 28,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1F22),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.search, size: 16, color: Color(0xFF949BA4)),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 100),
              child: sidebarBuilder != null
                  ? (sidebarBuilder(context) ?? const _DefaultSidebarContent())
                  : const _DefaultSidebarContent(),
            ),
          ),
        ],
      ),
    );
  }
}

class _DefaultSidebarContent extends StatefulWidget {
  const _DefaultSidebarContent();

  @override
  State<_DefaultSidebarContent> createState() => _DefaultSidebarContentState();
}

class _DefaultSidebarContentState extends State<_DefaultSidebarContent> {
  @override
  Widget build(BuildContext context) {
    final dataProvider = context.watch<DataProvider>();

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      children: [
        _SidebarNavItem(
          icon: Icons.people,
          label: 'Friends',
          isSelected: true,
          onTap: () {},
        ),
        const SizedBox(height: 16),
        _SidebarSection(title: 'Direct Messages', onAddPressed: () {}),
        for (final convo in dataProvider.conversations)
          _SidebarNavItem(
            icon: Icons.account_circle,
            label: convo.isGroup
                ? convo.name ?? 'Group Chat'
                : convo.participants.first.username,
            onTap: () {},
          ),
      ],
    );
  }
}

class _SidebarNavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SidebarNavItem({
    required this.icon,
    required this.label,
    this.isSelected = false,
    required this.onTap,
  });

  @override
  State<_SidebarNavItem> createState() => _SidebarNavItemState();
}

class _SidebarNavItemState extends State<_SidebarNavItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
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
              Text(
                widget.label,
                style: TextStyle(
                  color: widget.isSelected || _isHovered
                      ? const Color(0xFFDBDEE1)
                      : const Color(0xFF949BA4),
                  fontSize: 15,
                  fontWeight: widget.isSelected
                      ? FontWeight.w500
                      : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SidebarSection extends StatelessWidget {
  final String title;
  final VoidCallback? onAddPressed;

  const _SidebarSection({required this.title, this.onAddPressed});

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

/// Desktop user panel
class UserPanel extends StatefulWidget {
  const UserPanel({super.key});

  @override
  State<UserPanel> createState() => _UserPanelState();
}

class _UserPanelState extends State<UserPanel> {
  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.user;

    return Container(
      width: 72 + 300,
      height: 90,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      alignment: Alignment.center,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: const BoxDecoration(
          color: Color(0xFF232428),
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
        alignment: Alignment.center,
        child: GestureDetector(
          onTap: () {},
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: const Color(0xFF5865F2),
                      image: const DecorationImage(
                        image: NetworkImage("https://github.com/DwifteJB.png"),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: const Color(0xFF23A559),
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(
                          color: const Color(0xFF232428),
                          width: 3,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 10),
              Text(
                user?.username ?? 'User',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
