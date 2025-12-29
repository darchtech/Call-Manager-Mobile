import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import '../services/websocket_service.dart';
import '../utils/app_colors_new.dart';
import '../utils/text_styles_new.dart';
import '../widgets/websocket_status_widget.dart';

class WebSocketTestScreen extends StatefulWidget {
  const WebSocketTestScreen({super.key});

  @override
  State<WebSocketTestScreen> createState() => _WebSocketTestScreenState();
}

class _WebSocketTestScreenState extends State<WebSocketTestScreen> {
  final WebSocketService _wsService = WebSocketService.instance;
  final TextEditingController _messageController = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];

  @override
  void initState() {
    super.initState();
    // Auto-connect when screen loads
    _wsService.connect();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('WebSocket Test'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.info),
            onPressed: () => _showConnectionDialog(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Connection status
          const WebSocketStatusWidget(),

          // Connection controls
          Padding(
            padding: EdgeInsets.all(4.w),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _connect,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Connect'),
                  ),
                ),
                SizedBox(width: 2.w),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _disconnect,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Disconnect'),
                  ),
                ),
                SizedBox(width: 2.w),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _sendPing,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Ping'),
                  ),
                ),
              ],
            ),
          ),

          // Message input
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.w),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Enter message to send',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(width: 2.w),
                ElevatedButton(
                  onPressed: _sendMessage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Send'),
                ),
              ],
            ),
          ),

          // Messages list
          Expanded(
            child: Container(
              margin: EdgeInsets.all(4.w),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListView.builder(
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final message = _messages[index];
                  return Container(
                    margin: EdgeInsets.all(1.w),
                    padding: EdgeInsets.all(2.w),
                    decoration: BoxDecoration(
                      color: message['type'] == 'sent'
                          ? AppColors.primary.withOpacity(0.1)
                          : AppColors.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: message['type'] == 'sent'
                            ? AppColors.primary
                            : AppColors.success,
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              message['type'] == 'sent'
                                  ? Icons.send
                                  : Icons.call_received,
                              size: 16.sp,
                              color: message['type'] == 'sent'
                                  ? AppColors.primary
                                  : AppColors.success,
                            ),
                            SizedBox(width: 2.w),
                            Text(
                              message['type'] == 'sent' ? 'Sent' : 'Received',
                              style: TextStyles.bodySmall.copyWith(
                                fontWeight: FontWeight.bold,
                                color: message['type'] == 'sent'
                                    ? AppColors.primary
                                    : AppColors.success,
                              ),
                            ),
                            const Spacer(),
                            Text(message['time'], style: TextStyles.caption),
                          ],
                        ),
                        SizedBox(height: 1.h),
                        Text(message['content'], style: TextStyles.bodyMedium),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _connect() {
    _wsService.connect();
    _addMessage('Attempting to connect...', 'system');
  }

  void _disconnect() {
    _wsService.disconnect();
    _addMessage('Disconnected from server', 'system');
  }

  void _sendPing() {
    if (_wsService.isConnected) {
      _wsService.sendMessage('ping', {
        'clientTime': DateTime.now().toIso8601String(),
        'test': true,
      });
      _addMessage('Ping sent to server', 'sent');
    } else {
      _addMessage('Not connected to server', 'error');
    }
  }

  void _sendMessage() {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    if (_wsService.isConnected) {
      _wsService.sendMessage('test_message', {
        'content': message,
        'clientTime': DateTime.now().toIso8601String(),
      });
      _addMessage('Message: $message', 'sent');
      _messageController.clear();
    } else {
      _addMessage('Not connected to server', 'error');
    }
  }

  void _addMessage(String content, String type) {
    setState(() {
      _messages.add({
        'content': content,
        'type': type,
        'time': DateTime.now().toString().substring(11, 19),
      });
    });
  }

  void _showConnectionDialog() {
    showDialog(
      context: context,
      builder: (context) => const WebSocketStatusDialog(),
    );
  }
}
