import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:window_manager/window_manager.dart';

import 'package:provider/provider.dart';

import 'package:hindsightchat/components/Colours.dart';

class DesktopTitlebar extends StatefulWidget {
  const DesktopTitlebar({super.key});

  @override
  State<DesktopTitlebar> createState() => _DesktopTitlebarState();
}

class _DesktopTitlebarState extends State<DesktopTitlebar> with WindowListener {
  bool _isMaximized = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _init();
  }

  Future<void> _init() async {
    _isMaximized = await windowManager.isMaximized();
    setState(() {});
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowMaximize() {
    setState(() => _isMaximized = true);
  }

  @override
  void onWindowUnmaximize() {
    setState(() => _isMaximized = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final isMacOS = !kIsWeb && Platform.isMacOS;

    return Container(
      height: 32,
      decoration: BoxDecoration(
        color: DarkBackgroundColor,
        border: Border(
          bottom: BorderSide(color: theme.colors.border, width: 1),
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onPanStart: (_) => windowManager.startDragging(),
              onDoubleTap: () async {
                if (await windowManager.isMaximized()) {
                  windowManager.unmaximize();
                } else {
                  windowManager.maximize();
                }
              },
            ),
          ),

          Positioned(
            left: (isMacOS ? 80 : 12),
            top: 0,
            bottom: 0,
            child: Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.asset(
                  'assets/logo.png',
                  width: 22,
                  height: 22,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),

          if (!isMacOS)
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _WindowButton(
                    icon: FIcons.minus,
                    iconSize: 16,
                    onPressed: () => windowManager.minimize(),
                    hoverColor: theme.colors.secondary,
                  ),
                  _WindowButton(
                    icon: _isMaximized ? FIcons.copy : FIcons.square,
                    iconSize: _isMaximized ? 14 : 14,
                    onPressed: () async {
                      if (await windowManager.isMaximized()) {
                        windowManager.unmaximize();
                      } else {
                        windowManager.maximize();
                      }
                    },
                    hoverColor: theme.colors.secondary,
                  ),
                  _WindowButton(
                    icon: FIcons.x,
                    iconSize: 16,
                    onPressed: () => windowManager.close(),
                    hoverColor: theme.colors.destructive,
                    hoverIconColor: Colors.white,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _WindowButton extends StatefulWidget {
  final IconData icon;
  final double iconSize;
  final VoidCallback onPressed;
  final Color hoverColor;
  final Color? hoverIconColor;

  const _WindowButton({
    required this.icon,
    required this.iconSize,
    required this.onPressed,
    required this.hoverColor,
    this.hoverIconColor,
  });

  @override
  State<_WindowButton> createState() => _WindowButtonState();
}

class _WindowButtonState extends State<_WindowButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onPressed,
        child: Container(
          width: 46,
          height: 40,
          color: _isHovered ? widget.hoverColor : Colors.transparent,
          child: Center(
            child: Icon(
              widget.icon,
              size: widget.iconSize,
              color: _isHovered && widget.hoverIconColor != null
                  ? widget.hoverIconColor
                  : theme.colors.foreground,
            ),
          ),
        ),
      ),
    );
  }
}

class _TitlebarIconButton extends StatefulWidget {
  final IconData? icon;
  final VoidCallback onPressed;
  final Widget? iconImage;

  const _TitlebarIconButton({
    this.icon,
    required this.onPressed,
    this.iconImage,
  });

  @override
  State<_TitlebarIconButton> createState() => _TitlebarIconButtonState();
}

class _TitlebarIconButtonState extends State<_TitlebarIconButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onPressed,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: _isHovered ? theme.colors.secondary : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Center(
            child: widget.icon != null
                ? Icon(widget.icon, size: 16, color: theme.colors.foreground)
                : (widget.iconImage ?? const SizedBox()),
          ),
        ),
      ),
    );
  }
}
