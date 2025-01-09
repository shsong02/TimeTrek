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
import 'package:intl/intl.dart';

class ChatAIAgent extends StatefulWidget {
  const ChatAIAgent({
    super.key,
    this.width,
    this.height,
    this.onGoalSelected,
    this.onActionsSelected,
  });

  final double? width;
  final double? height;
  final Function(String)? onGoalSelected;
  final Function(List<String>)? onActionsSelected;

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

        // 첫 번째 Goal을 기본값으로 설정
        if (goalNames.isNotEmpty && selectedGoal == null) {
          selectedGoal = goalNames[0];
          // 선택된 Goal의 모든 Action 자동 선택
          selectedActions = actionList
              .where((action) => action['goal_name'] == selectedGoal)
              .map((action) => action['action_name'] as String)
              .toList();

          // 상위 위젯에 선택 상태 전달
          widget.onGoalSelected?.call(selectedGoal!);
          widget.onActionsSelected?.call(selectedActions);
        }
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
    return GestureDetector(
      onTap: () {
        // 포커스 해제
        FocusScope.of(context).unfocus();
      },
      child: Portal(
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
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
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
                        child: TextField(
                          autofocus: false,
                          controller: _messageController,
                          focusNode: _focusNode,
                          decoration: InputDecoration(
                            hintText: '메시지를 입력하세요...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(25),
                              borderSide: BorderSide(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(25),
                              borderSide: BorderSide(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withOpacity(0.5),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(25),
                              borderSide: BorderSide(
                                color: Theme.of(context).colorScheme.primary,
                                width: 2,
                              ),
                            ),
                            filled: true,
                            fillColor: Theme.of(context).colorScheme.surface,
                          ),
                          onSubmitted: _sendMessage,
                          onChanged: (value) {
                            // 필요한 경우 여기에 추가 로직
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
      final db = FirebaseFirestore.instance;
      Map<String, dynamic>? goalInfo;
      List<Map<String, dynamic>> actionInfo = [];
      List<Map<String, dynamic>> calendarEvents = [];

      // goal_info 가져오기
      if (selectedGoal != null) {
        final goalDoc = await db
            .collection('goal_list')
            .where('name', isEqualTo: selectedGoal)
            .get();
        if (goalDoc.docs.isNotEmpty) {
          goalInfo = goalDoc.docs.first.data();
          // Timestamp를 ISO 문자열로 변환
          if (goalInfo!['created_at'] != null) {
            goalInfo!['created_at'] = (goalInfo!['created_at'] as Timestamp)
                .toDate()
                .toIso8601String();
          }
        }

        // 디버깅을 위한 로그 추가
        print('Selected Goal: $selectedGoal');
        print('Goal Info: $goalInfo');
      }

      // action_info 가져오기
      if (selectedActions.isNotEmpty) {
        // 디버깅을 위한 로그 추가
        print('Selected Actions: $selectedActions');

        final Query query = db.collection('action_list');

        if (selectedActions.length ==
            actionList
                .where((action) => action['goal_name'] == selectedGoal)
                .length) {
          // 모든 Action이 선택된 경우: goal_name으로만 필터링
          final actionDocs =
              await query.where('goal_name', isEqualTo: selectedGoal).get();
          actionInfo = actionDocs.docs
              .map((doc) => doc.data() as Map<String, dynamic>)
              .toList();
        } else {
          // 특정 Action들이 선택된 경우: goal_name과 action_name으로 필터링
          final actionDocs = await query
              .where('goal_name', isEqualTo: selectedGoal)
              .where('action_name', whereIn: selectedActions)
              .get();
          actionInfo = actionDocs.docs
              .map((doc) => doc.data() as Map<String, dynamic>)
              .toList();
        }

        print('Action Info: $actionInfo');
      }

      // calendar_event 가져오기
      if (selectedActions.isNotEmpty) {
        // 기본 쿼리 시작
        Query query = db
            .collection('calendar_event')
            .where('action_name', whereIn: selectedActions);

        // startTime이 있는 경우에만 조건 추가
        if (startTime != null) {
          query = query.where('startTime', isGreaterThanOrEqualTo: startTime);
        }

        // endTime이 있는 경우에만 조건 추가
        if (endTime != null) {
          query = query.where('endTime', isLessThanOrEqualTo: endTime);
        }

        final calendarDocs = await query.get();
        calendarEvents = calendarDocs.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          // Timestamp를 ISO 문자열로 변환
          if (data['startTime'] != null) {
            data['startTime'] =
                (data['startTime'] as Timestamp).toDate().toIso8601String();
          }
          if (data['endTime'] != null) {
            data['endTime'] =
                (data['endTime'] as Timestamp).toDate().toIso8601String();
          }
          return data;
        }).toList();
      }

      // 채팅 히스토리 구성
      final chatHistory = messages
          .take(10)
          .map((m) => {
                'text': m.text,
                'isUser': m.isUser,
                'timestamp': m.timestamp.toIso8601String(),
              })
          .toList();

      // API 요청 본문 구성
      final requestBody = {
        'goal_info': goalInfo,
        'action_info': actionInfo,
        'calendar_event': calendarEvents,
        'chat_history': chatHistory,
        'chat': text,
      };

      final response = await http.post(
        Uri.parse('https://shsong83.app.n8n.cloud/webhook-test/chat-message'),
        body: jsonEncode(requestBody), // JSON 문자열로 인코딩
        headers: {'Content-Type': 'application/json'}, // 헤더 추가
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
    // 디버깅을 위한 로그 추가
    print('현재입(create, delete, edit)에 따른 처리');
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
  List<String> selectedActions = [];
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

  // 모든 필수 값이 선택되었는지 확인하는 메서드 추가
  bool get isValid => selectedGoal != null && selectedActions.isNotEmpty;

  // 상위 위젯에 상태 변경을 알리는 메서드
  void _notifyParent() {
    if (isValid) {
      widget.onGoalSelected(selectedGoal!);
      widget.onActionsSelected(selectedActions);
      if (startDate != null && endDate != null) {
        widget.onTimeRangeSelected(startDate!, endDate!);
      }
    }
  }

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

        // 첫 번째 Goal을 기본값으로 설정
        if (goalNames.isNotEmpty && selectedGoal == null) {
          selectedGoal = goalNames[0];
          // 선택된 Goal의 모든 Action 자동 선택
          selectedActions = actionList
              .where((action) => action['goal_name'] == selectedGoal)
              .map((action) => action['action_name'] as String)
              .toList();

          // 상위 위젯에 선택 상태 전달
          widget.onGoalSelected(selectedGoal!);
          widget.onActionsSelected(selectedActions);
        }
      });
    } catch (e) {
      print('목표 및 액션 로딩 오류: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
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
                  value: selectedGoal,
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
                      // Goal이 선택되면 해당 Goal의 모든 Action을 자동으로 선택
                      selectedActions = actionList
                          .where((action) => action['goal_name'] == value)
                          .map((action) => action['action_name'] as String)
                          .toList();
                    });
                    if (value != null) {
                      widget.onGoalSelected(value);
                      // Action 선택 상태도 상위 위젯에 알림
                      widget.onActionsSelected(selectedActions);
                    }
                  },
                ),
              ),
              const SizedBox(height: 12),
              if (selectedGoal != null)
                _buildSection(
                  title: 'Action 선택',
                  subtitle: 'AI Chat 에게 질문하고 싶은 Action 을 선택하세요',
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Theme.of(context).primaryColor.withOpacity(0.5),
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: actionList
                          .where(
                              (action) => action['goal_name'] == selectedGoal)
                          .map((action) {
                        final actionName = action['action_name'] as String;
                        final isSelected = selectedActions.contains(actionName);
                        return FilterChip(
                          label: Text(
                            actionName,
                            style: TextStyle(
                              fontSize: 12,
                              color: isSelected
                                  ? Theme.of(context).colorScheme.onPrimary
                                  : Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          selected: isSelected,
                          onSelected: (bool selected) {
                            setState(() {
                              if (selected) {
                                selectedActions.add(actionName);
                              } else {
                                selectedActions.remove(actionName);
                              }
                              // 아무것도 선택되지 않았다면 모두 선택
                              if (selectedActions.isEmpty) {
                                selectedActions = actionList
                                    .where((action) =>
                                        action['goal_name'] == selectedGoal)
                                    .map((action) =>
                                        action['action_name'] as String)
                                    .toList();
                              }
                            });
                            widget.onActionsSelected(selectedActions);
                          },
                          backgroundColor:
                              Theme.of(context).colorScheme.surface,
                          selectedColor: Theme.of(context).colorScheme.primary,
                          checkmarkColor:
                              Theme.of(context).colorScheme.onPrimary,
                        );
                      }).toList(),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              _buildSection(
                title: '기간 설정',
                subtitle: 'AI Chat 에게 질문하기 위한 날짜 범위를 선택하세요',
                child: Material(
                  child: TextButton(
                    onPressed: () async {
                      final DateTimeRange? picked = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(DateTime.now().year - 1),
                        lastDate: DateTime(DateTime.now().year + 1),
                        initialDateRange: startDate != null && endDate != null
                            ? DateTimeRange(start: startDate!, end: endDate!)
                            : DateTimeRange(
                                start: DateTime.now(),
                                end: DateTime.now(),
                              ),
                        builder: (BuildContext context, Widget? child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme:
                                  Theme.of(context).colorScheme.copyWith(
                                        primary: Theme.of(context).primaryColor,
                                      ),
                            ),
                            child: SizedBox(
                              width: MediaQuery.of(context).size.width * 0.3,
                              height: MediaQuery.of(context).size.height * 0.3,
                              child: child!,
                            ),
                          );
                        },
                      );

                      if (picked != null) {
                        setState(() {
                          startDate = picked.start;
                          endDate = picked.end;
                        });
                        if (startDate != null && endDate != null) {
                          widget.onTimeRangeSelected(startDate!, endDate!);
                        }
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color:
                              Theme.of(context).primaryColor.withOpacity(0.5),
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              startDate != null && endDate != null
                                  ? '${DateFormat('yyyy-MM-dd').format(startDate!)} ~ ${DateFormat('yyyy-MM-dd').format(endDate!)}'
                                  : '날짜를 선택하세요',
                              style: TextStyle(
                                color: startDate != null
                                    ? Theme.of(context)
                                        .textTheme
                                        .bodyLarge
                                        ?.color
                                    : Theme.of(context).hintColor,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.calendar_today,
                            color: Theme.of(context).primaryColor,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // 필수 값이 모두 선택되지 않았을 때 경고 메시지 표시
        if (!isValid)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              '채팅을 시작하기 전에 Goal과 Action을 선택해주세요.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 12,
              ),
            ),
          ),
      ],
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
