import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:hindsightchat/providers/DataProvider.dart';
import 'package:provider/provider.dart';

class AddFriendPage extends StatefulWidget {
  const AddFriendPage({super.key});

  @override
  State<AddFriendPage> createState() => _AddFriendPageState();
}

class _AddFriendPageState extends State<AddFriendPage> {
  bool _isSendingRequest = false;
  String _statusMessage = '';
  final TextEditingController _usernameController = TextEditingController();

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  void sendFriendRequest() async {
    if (_isSendingRequest) return;

    if (_usernameController.text.trim().isEmpty) {
      setState(() => _statusMessage = 'Please enter a username');
      return;
    }

    if (!_usernameController.text.contains('.')) {
      setState(
        () =>
            _statusMessage = 'Please enter a valid username (user.example.com)',
      );
      return;
    }

    // check if 3 letters atleast
    if (_usernameController.text.split('.').first.length < 3) {
      setState(() => _statusMessage = 'Username must be at least 3 characters');
      return;
    }

    setState(() {
      _isSendingRequest = true;
      _statusMessage = 'Sending friend request...';
    });

    DataProvider provider = context.read<DataProvider>();

    bool success = await provider.sendFriendRequest(
      username: _usernameController.text.trim(),
    );
    setState(() {
      _isSendingRequest = false;
      _statusMessage = success
          ? 'Friend request sent successfully'
          : 'Could not send friend request. Please check the username and try again.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,

        children: [
          Row(
            children: [
              Expanded(
                child: FTextField(
                  control: .managed(controller: _usernameController),
                  hint: 'Enter user.example.com',
                ),
              ),
              const SizedBox(width: 8),
              FButton(
                onPress: sendFriendRequest,
                variant: _isSendingRequest ? .ghost : .outline,
                child: Text('Send Request'),
              ),
            ],
          ),
          if (_statusMessage.isNotEmpty) ...[
            const SizedBox(height: 16),
            // container with white border and padding
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.redAccent, width: 1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(_statusMessage),
            ),
          ],
        ],
      ),
    );
  }
}
