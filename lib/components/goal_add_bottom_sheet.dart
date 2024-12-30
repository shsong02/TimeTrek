import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../pages/actions/create_action.dart'; // CalendarConstants를 위한 import

class GoalAddBottomSheet extends StatefulWidget {
  @override
  _GoalAddBottomSheetState createState() => _GoalAddBottomSheetState();
}

class _GoalAddBottomSheetState extends State<GoalAddBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  bool isActionMode = false; // 토글을 위한 상태 추가

  // Goal 관련 상태
  String goalName = '';
  String description = '';
  String selectedTimeGroup = 'group-1';
  final TextEditingController _tagController = TextEditingController();
  List<String> tags = [];

  // Action 관련 상태 추가
  String selectedGoalName = '';
  String actionName = '';
  String actionDescription = '';
  double actionExecutionTime = 0.0;
  List<String> goalNames = []; // 목표 목록을 저장할 리스트

  @override
  void initState() {
    super.initState();
    _loadGoalNames(); // 목표 목록 로드
  }

  // 목표 목록을 로드하는 메서드
  Future<void> _loadGoalNames() async {
    final snapshot =
        await FirebaseFirestore.instance.collection('goal_list').get();
    setState(() {
      goalNames =
          snapshot.docs.map((doc) => doc.data()['name'] as String).toList();
      if (goalNames.isNotEmpty) {
        selectedGoalName = goalNames.first;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 토글 스위치
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isActionMode ? 'Create action' : 'Create goal',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Switch(
                  value: isActionMode,
                  onChanged: (value) {
                    setState(() {
                      isActionMode = value;
                    });
                  },
                ),
              ],
            ),

            // 조건부 폼 필드
            if (isActionMode) ...[
              // Action 생성 폼
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'Goal Name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                value: selectedGoalName,
                items: goalNames.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedGoalName = value!;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select a goal';
                  }
                  return null;
                },
              ),
              SizedBox(height: 12),
              TextFormField(
                decoration: InputDecoration(
                  labelText: 'Action Name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter action name';
                  }
                  return null;
                },
                onSaved: (value) => actionName = value ?? '',
              ),
              SizedBox(height: 12),
              TextFormField(
                decoration: InputDecoration(
                  labelText: 'Action Description',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                maxLines: 3,
                onSaved: (value) => actionDescription = value ?? '',
              ),
              SizedBox(height: 12),
              TextFormField(
                decoration: InputDecoration(
                  labelText: 'Execution Time (hours)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter execution time';
                  }
                  final time = double.tryParse(value);
                  if (time == null || time <= 0) {
                    return 'Please enter a valid time';
                  }
                  return null;
                },
                onSaved: (value) =>
                    actionExecutionTime = double.parse(value ?? '0'),
              ),
            ] else ...[
              // Goal 생성 폼
              TextFormField(
                decoration: InputDecoration(
                  labelText: 'Goal Name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter goal name';
                  }
                  return null;
                },
                onSaved: (value) => goalName = value ?? '',
              ),
              SizedBox(height: 12),
              TextFormField(
                decoration: InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter description';
                  }
                  return null;
                },
                onSaved: (value) => description = value ?? '',
              ),
              SizedBox(height: 12),
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'Time Group',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                value: selectedTimeGroup,
                items: CalendarConstants.timeGroups.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedTimeGroup = value!;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select a time group';
                  }
                  return null;
                },
              ),
              SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _tagController,
                      decoration: InputDecoration(
                        labelText: 'Add Tag',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(Icons.add),
                          onPressed: () => _addTag(),
                        ),
                      ),
                      onFieldSubmitted: (value) => _addTag(), // 엔터 키 입력 시 태그 추가
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              if (tags.isNotEmpty)
                Wrap(
                  spacing: 8,
                  children: tags
                      .map((tag) => Chip(
                            label: Text(tag),
                            onDeleted: () {
                              setState(() {
                                tags.remove(tag);
                              });
                            },
                          ))
                      .toList(),
                )
            ],
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel'),
                ),
                SizedBox(width: 12),
                ElevatedButton(
                  onPressed: isActionMode ? _submitActionForm : _submitGoalForm,
                  child: Text(isActionMode ? 'Create Action' : 'Create Goal'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[700],
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Action 생성을 위한 메서드
  Future<void> _submitActionForm() async {
    if (_formKey.currentState?.validate() ?? false) {
      _formKey.currentState?.save();

      try {
        // 선택된 goal의 timegroup 가져오기
        final goalDoc = await FirebaseFirestore.instance
            .collection('goal_list')
            .where('name', isEqualTo: selectedGoalName)
            .get();

        final timegroup = goalDoc.docs.first.data()['timegroup'] as String;

        // 현재 goal의 action 개수 확인
        final actionSnapshot = await FirebaseFirestore.instance
            .collection('action_list')
            .where('goal_name', isEqualTo: selectedGoalName)
            .get();

        final order = actionSnapshot.docs.length + 1;

        // Action 생성
        await FirebaseFirestore.instance.collection('action_list').add({
          'action_name': actionName,
          'action_description': actionDescription,
          'action_execution_time': actionExecutionTime,
          'action_status': 'created',
          'goal_name': selectedGoalName,
          'timegroup': timegroup,
          'action_reason': null,
          'order': order,
          'created_at': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Action added successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error occurred: $e')),
          );
        }
      }
    }
  }

  Future<void> _submitGoalForm() async {
    if (_formKey.currentState?.validate() ?? false) {
      _formKey.currentState?.save();
      try {
        await FirebaseFirestore.instance.collection('goal_list').add({
          'name': goalName,
          'description': description,
          'timegroup': selectedTimeGroup,
          'order': 1,
          'tag': tags,
          'created_at': FieldValue.serverTimestamp(),
        });
        if (mounted) {
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error occurred: $e')),
          );
        }
      }
    }
  }

  // GoalAddBottomSheet 클래스 내에 메서드 추가
  void _addTag() {
    final tag = _tagController.text.trim();
    if (tag.isNotEmpty && !tags.contains(tag)) {
      setState(() {
        tags.add(tag);
        _tagController.clear();
      });
    }
  }
}