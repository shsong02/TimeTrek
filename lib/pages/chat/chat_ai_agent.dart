import 'package:flutter/services.dart';

import 'package:http/http.dart' as http;
import 'package:multi_trigger_autocomplete/multi_trigger_autocomplete.dart';
import 'package:flutter_portal/flutter_portal.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:vega_multi_dropdown/multi_dropdown.dart';

class ChatAIAgent extends StatefulWidget {
  const ChatAIAgent({
    super.key,
    this.width,
    this.height,
  });

  final double? width;
  final double? height;

  @override
  State<ChatAIAgent> createState() => _ChatAIAgentState();
}

class _ChatAIAgentState extends State<ChatAIAgent> {
  final List<ChatMessage> messages = [];
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  // 자동완성 트리거 옵션들
  final List<String> scheduleCommands = ['조회', '생성', '삭제'];

  int _messageHistoryIndex = -1; // 메시지 히스토리 인덱스 추가
  String _currentInputCache = ''; // 현재 입력 중인 텍스트 캐시

  // TargetQuestionControl 관련 태 추가
  String? selectedGoal;
  List<String> selectedActions = [];
  DateTime? startTime;
  DateTime? endTime;

  // API 응답 처리를 위한 타입 정의
  Map<String, dynamic>? lastApiResponse;

  // Firestore 데이터를 저장할 변수들
  List<String> goalNames = [];
  List<Map<String, dynamic>> actionList = [];

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        _messageHistoryIndex = -1;
      }
    });
    _loadGoalsAndActions();
  }

  Future<void> _loadGoalsAndActions() async {
    try {
      // action_list 컬렉션에서 고유한 goal_name 목록 가져오기
      final actionListRef =
          FirebaseFirestore.instance.collection('action_list');
      final actionDocs = await actionListRef.get();

      // 중복 제거된 goal_name 목록 생성
      final uniqueGoals = actionDocs.docs
          .map((doc) => doc.data()['goal_name'] as String)
          .toSet()
          .toList();

      setState(() {
        goalNames = uniqueGoals;
        actionList = actionDocs.docs
            .map((doc) => doc.data() as Map<String, dynamic>)
            .toList();
      });
    } catch (e) {
      print('목표 및 액션 로딩 오류: $e');
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Portal(
      child: SizedBox(
        width: widget.width ?? double.infinity,
        height: widget.height ?? double.infinity,
        child: Column(
          children: [
            Card(
              margin: const EdgeInsets.all(4.0),
              elevation: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Text(
                      'AI Chat 질문 패널',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Divider(),
                  TargetQuestionControl(
                    onGoalSelected: (goal) =>
                        setState(() => selectedGoal = goal),
                    onActionsSelected: (actions) =>
                        setState(() => selectedActions = actions),
                    onTimeRangeSelected: (start, end) {
                      setState(() {
                        startTime = start;
                        endTime = end;
                      });
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: Card(
                margin: const EdgeInsets.all(8.0),
                elevation: 2,
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
                    const Divider(),
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
                                              MultiTriggerAutocomplete.of(
                                                  context);
                                          autocomplete.acceptAutocompleteOption(
                                              command);
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
                          return CallbackShortcuts(
                            bindings: {
                              SingleActivator(LogicalKeyboardKey.arrowUp): () =>
                                  _handleUpArrow(controller),
                              SingleActivator(LogicalKeyboardKey.arrowDown):
                                  () => _handleDownArrow(controller),
                            },
                            child: TextField(
                              controller: controller,
                              focusNode: focusNode,
                              decoration: InputDecoration(
                                hintText: '메시지를 입력하세요...',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(25),
                                  borderSide: BorderSide(
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(25),
                                  borderSide: BorderSide(
                                    color: theme.colorScheme.primary
                                        .withOpacity(0.5),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(25),
                                  borderSide: BorderSide(
                                    color: theme.colorScheme.primary,
                                    width: 2,
                                  ),
                                ),
                                filled: true,
                                fillColor: theme.colorScheme.surface,
                              ),
                              onSubmitted: (text) => _sendMessage(text),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
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

    _messageController.clear();
    _scrollToBottom();

    try {
      String type = 'default';
      String message = text;

      if (text.startsWith('#조회')) {
        type = 'get';
        message = text.replaceFirst('#조회', '').trim();
      } else if (text.startsWith('#생성')) {
        type = 'add';
        message = text.replaceFirst('#생성', '').trim();
      } else if (text.startsWith('#삭제')) {
        type = 'delete';
        message = text.replaceFirst('#삭제', '').trim();
      }

      // API 요청 본 수정
      final requestBody = {
        'message': message,
        'type': type,
        'goal_info': selectedGoal,
        'action_info': selectedActions,
        'calendar_event': {
          'startTime': startTime?.toIso8601String(),
          'endTime': endTime?.toIso8601String(),
        },
        'chat_history': messages
            .take(10)
            .map((m) => {
                  'text': m.text,
                  'isUser': m.isUser,
                })
            .toList(),
        'chat': text,
      };

      final response = await http.post(
        Uri.parse('https://shsong83.app.n8n.cloud/webhook-test/chat-message'),
        body: requestBody,
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        lastApiResponse = responseData;

        // 채팅 응답 표시
        setState(() {
          messages.add(ChatMessage(
            text: responseData['chat_response'],
            isUser: false,
            timestamp: DateTime.now(),
          ));
        });

        // edit_action 처리
        if (responseData['edit_action'] != null) {
          _processEditActions(responseData['edit_action']);
        }

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

  void _processEditActions(List<Map<String, dynamic>> actions) {
    // TODO: action_list 컬렉션 업데이트 로직 구현
    // 각 액션 타입(create, delete, edit)에 따른 처리
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
    final theme = Theme.of(context);

    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: message.isUser
              ? theme.colorScheme.primary
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: theme.shadowColor.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(
            color: message.isUser
                ? Colors.transparent
                : theme.colorScheme.outline.withOpacity(0.2),
          ),
        ),
        child: Text(
          message.text,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: message.isUser
                ? theme.colorScheme.onPrimary
                : theme.colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}

// TargetQuestionControl 위 구현
class TargetQuestionControl extends StatefulWidget {
  final Function(String) onGoalSelected;
  final Function(List<String>) onActionsSelected;
  final Function(DateTime, DateTime) onTimeRangeSelected;

  const TargetQuestionControl({
    required this.onGoalSelected,
    required this.onActionsSelected,
    required this.onTimeRangeSelected,
    super.key,
  });

  @override
  State<TargetQuestionControl> createState() => _TargetQuestionControlState();
}

class _TargetQuestionControlState extends State<TargetQuestionControl> {
  String? selectedGoal;
  List<String> selectedActions = ['ALL'];
  DateTime? startDate;
  DateTime? endDate;
  List<String> goalNames = [];
  List<Map<String, dynamic>> actionList = [];

  // 목표 및 액션 데이터 (실제로는 Firestore에서 가져와야 함)
  final List<Map<String, dynamic>> goals = [];
  final List<Map<String, dynamic>> actions = [];

  // 임시 날짜 장을 위한 변수 추가
  DateTime? tempStartDate;
  DateTime? tempEndDate;

  final MultiSelectController<String> _actionController =
      MultiSelectController<String>();

  @override
  void initState() {
    super.initState();
    _loadGoalsAndActions();
  }

  Future<void> _loadGoalsAndActions() async {
    try {
      final actionListRef =
          FirebaseFirestore.instance.collection('action_list');
      final actionDocs = await actionListRef.get();

      // 중복 제거된 goal_name 목록 생성
      final uniqueGoals = actionDocs.docs
          .map((doc) => doc.data()['goal_name'] as String)
          .toSet()
          .toList();

      setState(() {
        goalNames = uniqueGoals;
        actionList = actionDocs.docs
            .map((doc) => doc.data() as Map<String, dynamic>)
            .toList();
      });
    } catch (e) {
      print('목표 및 액션 로딩 오류: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSection(
            title: 'Goal 선택',
            subtitle: 'AI Chat 에게 질문하고 싶은 Goal 를 선택하세요',
            child: DropdownButtonFormField<String>(
              isDense: true,
              menuMaxHeight: 150,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
              ),
              items: goalNames.map<DropdownMenuItem<String>>((goalName) {
                return DropdownMenuItem(
                  value: goalName,
                  child: Text(
                    goalName,
                    style: const TextStyle(fontSize: 13),
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedGoal = value;
                  selectedActions = ['ALL'];
                });
                if (value != null) {
                  widget.onGoalSelected(value);
                }
              },
            ),
          ),
          const SizedBox(height: 12),
          if (selectedGoal != null)
            _buildSection(
              title: 'Action 선택',
              subtitle: 'AI Chat 에게 질문하고 싶은 Action 을 선택하세요',
              child: MultiDropdown<String>(
                controller: _actionController,
                items: [
                  DropdownItem<String>(
                    id: 'ALL',
                    value: 'ALL',
                    label: 'ALL',
                    selected: selectedActions.contains('ALL'),
                  ),
                  ...actionList
                      .where((action) => action['goal_name'] == selectedGoal)
                      .map((action) => DropdownItem<String>(
                            id: action['action_name'],
                            value: action['action_name'],
                            label: action['action_name'] as String,
                            selected:
                                selectedActions.contains(action['action_name']),
                          ))
                      .toList(),
                ],
                onSelectionChange: (items) {
                  setState(() {
                    if (items.any((item) => item == 'ALL')) {
                      selectedActions = ['ALL'];
                    } else {
                      selectedActions = items.toList();
                      if (selectedActions.isEmpty) {
                        selectedActions = ['ALL'];
                      }
                    }
                  });
                  widget.onActionsSelected(selectedActions);
                },
                searchEnabled: true,
                chipDecoration: ChipDecoration(
                  backgroundColor:
                      Theme.of(context).primaryColor.withOpacity(0.1),
                  labelStyle: TextStyle(
                    color: Theme.of(context).primaryColor,
                    fontSize: 12,
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  borderRadius: BorderRadius.circular(4),
                ),
                fieldDecoration: FieldDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: BorderSide(
                      color: Theme.of(context).primaryColor.withOpacity(0.5),
                    ),
                  ),
                  hintText: 'Action 선택...',
                ),
              ),
            ),
          const SizedBox(height: 12),
          _buildSection(
            title: '기간 설정',
            subtitle: 'AI Chat 에게 질문하기 위한 날짜 범위를 선택하세요',
            child: TextFormField(
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.calendar_today),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => Dialog(
                        child: SizedBox(
                          height: 400,
                          width: 400,
                          child: SfDateRangePicker(
                            onSelectionChanged:
                                (DateRangePickerSelectionChangedArgs args) {
                              if (args.value is PickerDateRange) {
                                final range = args.value as PickerDateRange;
                                setState(() {
                                  startDate = range.startDate;
                                  endDate = range.endDate ?? range.startDate;
                                });
                                if (startDate != null && endDate != null) {
                                  widget.onTimeRangeSelected(
                                      startDate!, endDate!);
                                }
                              }
                            },
                            selectionMode: DateRangePickerSelectionMode.range,
                            initialSelectedRange:
                                PickerDateRange(startDate, endDate),
                            showActionButtons: true,
                            cancelText: 'CANCEL',
                            confirmText: 'OK',
                            onCancel: () => Navigator.pop(context),
                            onSubmit: (value) => Navigator.pop(context),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              readOnly: true,
              controller: TextEditingController(
                text: startDate != null && endDate != null
                    ? '${startDate?.toString().split(' ')[0]} ~ ${endDate?.toString().split(' ')[0]}'
                    : '',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Tooltip(
          message: subtitle,
          child: Text(
            title,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
          ),
        ),
        const SizedBox(height: 3),
        child,
      ],
    );
  }
}

// 새로운 CustomMultiSelect 위젯 추가
class CustomMultiSelect extends StatefulWidget {
  final List<String> items;
  final List<String> selectedItems;
  final Function(List<String>) onChanged;

  const CustomMultiSelect({
    super.key,
    required this.items,
    required this.selectedItems,
    required this.onChanged,
  });

  @override
  State<CustomMultiSelect> createState() => _CustomMultiSelectState();
}

class _CustomMultiSelectState extends State<CustomMultiSelect> {
  bool _isExpanded = false;
  final LayerLink _layerLink = LayerLink();

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: Column(
        children: [
          GestureDetector(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: widget.selectedItems.map((item) {
                        return Chip(
                          label:
                              Text(item, style: const TextStyle(fontSize: 12)),
                          onDeleted: () {
                            final newSelection =
                                List<String>.from(widget.selectedItems)
                                  ..remove(item);
                            widget.onChanged(
                                newSelection.isEmpty ? ['ALL'] : newSelection);
                          },
                        );
                      }).toList(),
                    ),
                  ),
                  Icon(_isExpanded
                      ? Icons.arrow_drop_up
                      : Icons.arrow_drop_down),
                ],
              ),
            ),
          ),
          if (_isExpanded)
            CompositedTransformFollower(
              link: _layerLink,
              targetAnchor: Alignment.bottomLeft,
              followerAnchor: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 200),
                    width: MediaQuery.of(context).size.width,
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: widget.items.length,
                      itemBuilder: (context, index) {
                        final item = widget.items[index];
                        final isSelected = widget.selectedItems.contains(item);

                        return CheckboxListTile(
                          title:
                              Text(item, style: const TextStyle(fontSize: 13)),
                          value: isSelected,
                          dense: true,
                          onChanged: (bool? value) {
                            if (item == 'ALL') {
                              widget.onChanged(['ALL']);
                            } else {
                              final newSelection =
                                  List<String>.from(widget.selectedItems);
                              if (value == true) {
                                newSelection.remove('ALL');
                                newSelection.add(item);
                              } else {
                                newSelection.remove(item);
                              }
                              widget.onChanged(newSelection.isEmpty
                                  ? ['ALL']
                                  : newSelection);
                            }
                          },
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
