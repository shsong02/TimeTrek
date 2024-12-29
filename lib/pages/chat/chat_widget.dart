import 'package:flutter/services.dart';

import 'package:http/http.dart' as http;
import 'package:multi_trigger_autocomplete/multi_trigger_autocomplete.dart';
import 'package:flutter_portal/flutter_portal.dart';
import 'package:flutter/material.dart';

class ChatWidget extends StatefulWidget {
  const ChatWidget({
    super.key,
    this.width,
    this.height,
  });

  final double? width;
  final double? height;

  @override
  State<ChatWidget> createState() => _ChatWidgetState();
}

class _ChatWidgetState extends State<ChatWidget> {
  final List<ChatMessage> messages = [];
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // 자동완성 트리거 옵션들
  final List<String> scheduleCommands = ['조회', '생성', '삭제'];

  int _messageHistoryIndex = -1; // 메시지 히스토리 인덱스 추가
  String _currentInputCache = ''; // 현재 입력 중인 텍스트 캐시

  @override
  Widget build(BuildContext context) {
    return Portal(
      child: SizedBox(
        width: widget.width ?? double.infinity,
        height: widget.height ?? double.infinity,
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final message = messages[index];
                  return MessageBubble(message: message);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: MultiTriggerAutocomplete(
                optionsAlignment: OptionsAlignment.topStart,
                autocompleteTriggers: [
                  AutocompleteTrigger(
                    trigger: '#',
                    optionsViewBuilder: (context, query, controller) {
                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.5),
                              spreadRadius: 1,
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: scheduleCommands.length,
                          itemBuilder: (context, index) {
                            final command = scheduleCommands[index];
                            return Material(
                              color: Colors.transparent,
                              child: ListTile(
                                title: Text(command),
                                onTap: () {
                                  final autocomplete =
                                      MultiTriggerAutocomplete.of(context);
                                  autocomplete
                                      .acceptAutocompleteOption(command);
                                },
                                focusColor: Colors.grey[200],
                                hoverColor: Colors.grey[200],
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ],
                fieldViewBuilder: (context, controller, focusNode) {
                  return Row(
                    children: [
                      Expanded(
                        child: RawKeyboardListener(
                          focusNode: FocusNode(),
                          onKey: (event) {
                            if (event is RawKeyDownEvent) {
                              if (event.logicalKey ==
                                  LogicalKeyboardKey.arrowUp) {
                                _handleUpArrow(controller);
                              }
                              if (event.logicalKey ==
                                  LogicalKeyboardKey.arrowDown) {
                                _handleDownArrow(controller);
                              }
                            }
                          },
                          child: TextField(
                            controller: controller,
                            focusNode: focusNode,
                            decoration: InputDecoration(
                              hintText: '메시지를 입력하세요...',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(25),
                              ),
                              filled: true,
                              fillColor: Colors.grey[200],
                            ),
                            onSubmitted: (text) => _sendMessage(text),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.send),
                        onPressed: () => _sendMessage(controller.text),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    setState(() {
      messages.add(ChatMessage(
        text: text,
        isUser: true,
        timestamp: DateTime.now(),
      ));
    });

    _controller.clear();
    _scrollToBottom();

    try {
      String type = 'default';
      String message = text;

      if (text.startsWith('조회')) {
        type = 'get';
        message = text.replaceFirst('조회', '').trim();
      } else if (text.startsWith('생성')) {
        type = 'add';
        message = text.replaceFirst('생성', '').trim();
      } else if (text.startsWith('삭제')) {
        type = 'delete';
        message = text.replaceFirst('삭제', '').trim();
      }

      final response = await http.post(
        Uri.parse('https://shsong83.app.n8n.cloud/webhook-test/chat-message'),
        body: {'message': message, 'type': type},
      );

      if (response.statusCode == 200) {
        setState(() {
          messages.add(ChatMessage(
            text: response.body,
            isUser: false,
            timestamp: DateTime.now(),
          ));
        });
        _scrollToBottom();
      }
    } catch (e) {
      print('Error sending message: $e');
      setState(() {
        messages.add(ChatMessage(
          text: '메시지 전송 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요.',
          isUser: false,
          timestamp: DateTime.now(),
        ));
      });
      _scrollToBottom();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('네트워크 오류가 발생했습니다'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  void _handleUpArrow(TextEditingController controller) {
    if (messages.isEmpty) return;

    // 첫 화살표 위 클릭시 현재 입력 텍스트 저장
    if (_messageHistoryIndex == -1) {
      _currentInputCache = controller.text;
    }

    // 유저 메시지만 필터링
    final userMessages =
        messages.where((m) => m.isUser).toList().reversed.toList();

    if (_messageHistoryIndex < userMessages.length - 1) {
      _messageHistoryIndex++;
      controller.text = userMessages[_messageHistoryIndex].text;
      controller.selection = TextSelection.fromPosition(
        TextPosition(offset: controller.text.length),
      );
    }
  }

  void _handleDownArrow(TextEditingController controller) {
    if (_messageHistoryIndex == -1) return;

    if (_messageHistoryIndex > 0) {
      _messageHistoryIndex--;
      final userMessages =
          messages.where((m) => m.isUser).toList().reversed.toList();
      controller.text = userMessages[_messageHistoryIndex].text;
    } else {
      _messageHistoryIndex = -1;
      controller.text = _currentInputCache;
    }

    controller.selection = TextSelection.fromPosition(
      TextPosition(offset: controller.text.length),
    );
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}

class MessageBubble extends StatelessWidget {
  final ChatMessage message;

  const MessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: message.isUser ? Colors.blue : Colors.grey[300],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          message.text,
          style: TextStyle(
            color: message.isUser ? Colors.white : Colors.black,
          ),
        ),
      ),
    );
  }
}
