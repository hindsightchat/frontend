import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:hindsightchat/providers/DataProvider.dart';
import 'package:provider/provider.dart';

Future<String?> showCreateConversationDialog(BuildContext context) async {
  return showFDialog<String?>(
    context: context,
    builder: (context, style, animation) =>
        _CreateConversationDialog(style: style, animation: animation),
  );
}

class _CreateConversationDialog extends StatefulWidget {
  final FDialogStyle style;
  final Animation<double> animation;

  const _CreateConversationDialog({
    required this.style,
    required this.animation,
  });

  @override
  State<_CreateConversationDialog> createState() =>
      _CreateConversationDialogState();
}

class _CreateConversationDialogState extends State<_CreateConversationDialog> {
  final Set<String> _selectedFriendIds = {};
  final TextEditingController _titleController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  bool get _isMultipleSelected => _selectedFriendIds.length > 1;

  void _toggleFriend(String visibleUserId) {
    setState(() {
      if (_selectedFriendIds.contains(visibleUserId)) {
        _selectedFriendIds.remove(visibleUserId);
      } else {
        _selectedFriendIds.add(visibleUserId);
      }
    });
  }

  Future<void> _onConfirm() async {
    if (_selectedFriendIds.isEmpty) return;

    final dataProvider = context.read<DataProvider>();

    if (_selectedFriendIds.length == 1) {
      // try find 1-1 conversation with this friend first
      final selectedUserId = _selectedFriendIds.first;
      final friendship = dataProvider.getFriendByUserId(selectedUserId);

      if (friendship != null && friendship.conversationId.isNotEmpty) {
        Navigator.of(context).pop(friendship.conversationId);
      }
    } else {
      // Multiple selection - create group
      setState(() => _isLoading = true);

      final title = _titleController.text.trim();
      final conversationId = await dataProvider.createConversation(
        userIds: _selectedFriendIds.toList(),
        title: title.isNotEmpty ? title : null,
      );

      setState(() => _isLoading = false);

      if (conversationId != null && mounted) {
        Navigator.of(context).pop(conversationId);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dataProvider = context.watch<DataProvider>();
    final friends = dataProvider.friends;
    final theme = context.theme;

    return FDialog.raw(
      style: widget.style,
      animation: widget.animation,
      semanticsLabel: 'Create Conversation',
      constraints: const BoxConstraints(minWidth: 320, maxWidth: 400),
      builder: (context, style) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Text(
              _isMultipleSelected ? 'Create Group' : 'Start Conversation',
              style: theme.typography.lg.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colors.foreground,
              ),
            ),
            const SizedBox(height: 4),

            // Group title input (only when multiple selected)
            if (_isMultipleSelected) ...[
              const SizedBox(height: 16),
              FTextField(
                controller: _titleController,
                label: const Text('Group Name (optional)'),
                hint: 'Enter group name...',
                maxLength: 20,
              ),
            ],

            const SizedBox(height: 16),

            // Friends list
            if (friends.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'No friends yet',
                    style: theme.typography.sm.copyWith(
                      color: theme.colors.mutedForeground,
                    ),
                  ),
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 300),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: friends.map((friendship) {
                      final user = dataProvider.getFriendUser(friendship);
                      final displayName =
                          user?.username ?? friendship.visibleUsername;
                      final isSelected = _selectedFriendIds.contains(
                        friendship.visibleUserId,
                      );

                      return _FriendCheckboxItem(
                        displayName: displayName,
                        isSelected: isSelected,
                        onToggle: () => _toggleFriend(friendship.visibleUserId),
                      );
                    }).toList(),
                  ),
                ),
              ),

            const SizedBox(height: 20),

            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FButton(
                  style: FButtonStyle.outline(),
                  onPress: () => Navigator.of(context).pop(null),
                  child: const Text('Back'),
                ),
                const SizedBox(width: 8),
                FButton(
                  onPress: _selectedFriendIds.isEmpty || _isLoading
                      ? null
                      : _onConfirm,
                  child: _isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_isMultipleSelected ? 'Create' : 'Confirm'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FriendCheckboxItem extends StatefulWidget {
  final String displayName;
  final bool isSelected;
  final VoidCallback onToggle;

  const _FriendCheckboxItem({
    required this.displayName,
    required this.isSelected,
    required this.onToggle,
  });

  @override
  State<_FriendCheckboxItem> createState() => _FriendCheckboxItemState();
}

class _FriendCheckboxItemState extends State<_FriendCheckboxItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onToggle,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: _isHovered || widget.isSelected
                ? theme.colors.secondary.withOpacity(0.5)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              // Checkbox indicator
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: widget.isSelected
                      ? theme.colors.primary
                      : Colors.transparent,
                  border: Border.all(
                    color: widget.isSelected
                        ? theme.colors.primary
                        : theme.colors.border,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: widget.isSelected
                    ? Icon(
                        Icons.check,
                        size: 14,
                        color: theme.colors.primaryForeground,
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: theme.colors.secondary,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: CircleAvatar(
                    radius: 14,
                    backgroundImage: const NetworkImage(
                      "https://github.com/HaiSuki.png",
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Name
              Expanded(
                child: Text(
                  widget.displayName,
                  style: theme.typography.sm.copyWith(
                    color: theme.colors.foreground,
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
