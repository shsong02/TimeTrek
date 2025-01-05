import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart'; // 추가된 import
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:math';
import '../../components/new_calendar_event.dart'; // 추가된 import
import '../../components/time_info_card.dart';
import 'package:flutter/material.dart';
import '../../components/goal_add_bottom_sheet.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:provider/provider.dart';
import '../../backend/app_state.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';  // 추가된 import
import '../../components/file_storage_utils.dart';

// 캘린더 관련 상수를 관리하는 클래스
class CalendarConstants {
  // 타임그룹 정의 수정
  static const timeGroups = [
    'group-1',
    'group-2',
    'group-3',
    'group-4',
  ];

  static String formatTimeGroup(String timegroup) {
    return timegroup; // 단순히 원래 값을 반환
  }

  // 각 타임그룹별 색상 정의 수정
  static final timeGroupColors = {
    'group-1': const Color(0xFF6366F1),
    'group-2': const Color(0xFFEC4899),
    'group-3': const Color(0xFF14B8A6),
    'group-4': const Color(0xFFF59E0B),
  };
}

class CreateAction extends StatefulWidget {
  const CreateAction({
    super.key,
    this.width,
    this.height,
  });

  final double? width;
  final double? height;

  @override
  State<CreateAction> createState() => _CreateActionState();
}

class _CreateActionState extends State<CreateAction> {
  // 목표 데이터를 저장하는 리스트
  List<GoalData> goals = [];
  // 현재 확장된 목표의 ID를 추적하는 ValueNotifier
  final ValueNotifier<String?> expandedGoalId = ValueNotifier<String?>(null);
  // 새로고침을 위한 ValueNotifier
  final ValueNotifier<bool> _refreshNotifier = ValueNotifier<bool>(false);
  // 각 그룹별 시간 정보를 저장하는 Map
  Map<String, double> _groupTimes = {};
  // 새로운 상태 변수 추가
  bool _isGeneratingActions = false;

  @override
  void initState() {
    super.initState();
    _loadData(); // 초기 데이터 로드
  }

  // 모든 필요한 데이터를 병렬로 로드하는 메서드
  Future<void> _loadData() async {
    try {
      await Future.wait([
        _loadGoals(), // 목표 데이터 로드
        _updateGroupTimes(), // 그룹별 시간 정보 업데이트
      ]);

      // 타임슬롯 계산 추가
      // final timeslotDocs = await calculateAvailableTimeSlots();
      // print('초기 로드된 타임슬롯 수: ${timeslotDocs.length}');

    } catch (e) {
      print('Error in _loadData: $e');
    }
  }

  // 목표 데이터를 로드하고 정렬하는 메서드
  Future<void> _loadGoals() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    // 현재 사용자의 goal만 조회하도록 수정
    final snapshot = await FirebaseFirestore.instance
        .collection('goal_list')
        .where('uid', isEqualTo: currentUser.uid)
        .get();

    final loadedGoals = await Future.wait(
        snapshot.docs.map((doc) => GoalData.fromDocument(doc)));

    if (mounted) {
      setState(() {
        goals = loadedGoals
          ..sort((a, b) {
            final timeGroupComparison = a.timegroup.compareTo(b.timegroup);
            if (timeGroupComparison != 0) return timeGroupComparison;
            return a.order.compareTo(b.order);
          });
      });
    }
  }

  // 그룹별 시간 정보를 업데이트하는 메서드
  Future<void> _updateGroupTimes() async {
    try {
      final newGroupTimes = <String, double>{};

      // 각 타임그룹의 기본값을 0.0으로 초기화
      for (var i = 1; i <= 4; i++) {
        newGroupTimes['group-$i'] = 0.0;
      }

      // 이번달의 시작일과 종료일 계산
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

      // 이번달의 timeslot 데이터 조회
      final timeslotsSnapshot = await FirebaseFirestore.instance
          .collection('timeslot')
          .where('startTime', isGreaterThanOrEqualTo: startOfMonth)
          .where('startTime', isLessThanOrEqualTo: endOfMonth)
          .get();

      // 각 timeslot의 시간을 계산하여 그룹별로 합산
      for (var doc in timeslotsSnapshot.docs) {
        final data = doc.data();
        final subject = data['subject'] as String?;

        if (subject != null) {
          final timegroup = subject; // 변환 없이 그대로 사용

          final startTime = (data['startTime'] as Timestamp).toDate();
          final endTime = (data['endTime'] as Timestamp).toDate();

          final duration = endTime.difference(startTime).inMinutes / 60.0;
          newGroupTimes[timegroup] =
              (newGroupTimes[timegroup] ?? 0.0) + duration;
        }
      }

      if (mounted) {
        setState(() {
          _groupTimes = newGroupTimes;
        });
      }
    } catch (e) {
      print('Error updating group times: $e');
    }
  }

  // 수정: _getGroupTimes 메서드
  Future<Map<String, double>> _getGroupTimes() async {
    return _groupTimes;
  }

  // 수정: FloatingActionButton onPressed 콜백
  Future<void> _handleGoalAdd() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: GoalAddBottomSheet(),
      ),
    );

    if (result == true) {
      await _loadData(); // 전체 데이터 새로고침
      _refreshNotifier.value = !_refreshNotifier.value;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: _refreshNotifier,
      builder: (context, _, __) {
        return FutureBuilder<List<Object>>(
          future: _getFutureValues(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            if (snapshot.data == null) {
              return Center(child: Text('No data available'));
            }

            final data = snapshot.data!;
            final totalActions = data[0] as int;
            final completedActions = data[1] as int;
            final completedGoals = data[2] as int;
            final groupTimes = data[3] as Map<String, double>;
            // final summary = data[4] as Map<String, dynamic>;

            // Timeslot 데이터 가져오기
            final groupExecutionTimes = <String, double>{};
            for (var goal in goals) {
              final group = goal.timegroup;
              final executionTime = goal.actions.fold<double>(0, (sum, action) {
                return sum + action.action_execution_time;
              });

              groupExecutionTimes[group] =
                  (groupExecutionTimes[group] ?? 0) + executionTime;
            }

            // print('\n최종 그룹별 실행 시간: $groupExecutionTimes');

            // 현재 날짜와 이번 달의 총 일수 가져오기
            final now = DateTime.now();
            final currentDay = now.day;
            final daysInMonth = DateUtils.getDaysInMonth(now.year, now.month);

            return Stack(
              children: [
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Time Allocation Card
                      Container(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.1),
                              spreadRadius: 2,
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 월간 진행도 슬라이더
                            Row(
                              children: [
                                Text(
                                  '${currentDay}일',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Expanded(
                                  child: Slider(
                                    value: currentDay.toDouble(),
                                    min: 1,
                                    max: daysInMonth.toDouble(),
                                    activeColor: Theme.of(context).primaryColor,
                                    onChanged: null,
                                  ),
                                ),
                                Text(
                                  '${daysInMonth}일',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),

                            // Goals & Actions 진행률
                            Row(
                              children: [
                                Expanded(
                                  child: _buildProgressIndicator(
                                    'Goals',
                                    completedGoals,
                                    goals.length,
                                    Colors.blue,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildProgressIndicator(
                                    'Actions',
                                    completedActions,
                                    totalActions,
                                    Colors.green,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),

                            // TimeGroup 진행률
                            FutureBuilder<Map<String, double>>(
                              future: _calculateAllRemainingTimes(),
                              builder: (context, snapshot) {
                                final remainingTimes = snapshot.data ?? {};
                                return Row(
                                  children: List.generate(
                                    CalendarConstants.timeGroups.length,
                                    (index) {
                                      final group =
                                          CalendarConstants.timeGroups[index];
                                      final totalTime =
                                          groupTimes[group] ?? 0.0;
                                      return Expanded(
                                        child: TimeInfoCard(
                                          timegroup: group,
                                          totalMonthlyTime: totalTime,
                                          remainingTime:
                                              remainingTimes[group] ?? 0.0,
                                          createdActionTime:
                                              _getCreatedActionTime(group),
                                          totalActionTime:
                                              _getTotalActionTime(group),
                                          groupColor: CalendarConstants
                                                  .timeGroupColors[group] ??
                                              Colors.grey,
                                        ),
                                      );
                                    },
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Service Buttons
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: ElevatedButton.icon(
                                onPressed: _handleCalendarPlacement,
                                icon: Icon(Icons.calendar_month, size: 20),
                                label: Text('캘린더 배치'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Theme.of(context).primaryColor,
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Container(
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: ElevatedButton.icon(
                                onPressed: _isGeneratingActions 
                                  ? null  // 생성 중일 때는 버튼 비활성화
                                  : () async {
                                      try {
                                        setState(() {
                                          _isGeneratingActions = true;  // 생성 시작
                                        });

                                        // 구조화된 그룹 데이터 준비
                                        final groupData = await prepareGroupData();

                                        // POST 요청 보내기
                                        final response = await http.post(
                                          // Uri.parse('https://shsong83.app.n8n.cloud/webhook-test/reqeust_actions'),
                                          Uri.parse('https://shsong83.app.n8n.cloud/webhook/reqeust_actions'),
                                          headers: {'Content-Type': 'application/json'},
                                          body: jsonEncode(groupData),
                                        );

                                        if (response.statusCode == 200) {
                                          print('데이터 전송 성공');
                                          print('답 데이터: ${response.body}');

                                          // 응답 데이터 파싱
                                          final responseData =
                                              jsonDecode(response.body)
                                                  as List<dynamic>;

                                          // Firestore batch 생성
                                          final batch =
                                              FirebaseFirestore.instance.batch();

                                          // 각 액션을 action_list 컬렉션에 추가
                                          for (var actionData in responseData) {
                                            final docRef = FirebaseFirestore
                                                .instance
                                                .collection('action_list')
                                                .doc();

                                            // 디버그 출력 추가
                                            print('저장할 액션 데이터:');
                                            print(
                                                'timegroup: ${actionData['timegroup']}');
                                            print(
                                                'action_reason: ${actionData['action_reason']}');

                                            batch.set(docRef, {
                                              'action_name':
                                                  actionData['action_name'],
                                              'action_description':
                                                  actionData['action_description'],
                                              'action_execution_time': actionData[
                                                  'action_execution_time'],
                                              'action_status': 'created',
                                              'goal_name': actionData['goal_name'],
                                              // timegroup과 action_reason이 null이 아닌 경우에만 저장
                                              'timegroup':
                                                  actionData['timegroup'] ?? '',
                                              'action_reason':
                                                  actionData['action_reason'] ?? '',
                                              'order': actionData['order'] ?? 1,
                                              'created_at':
                                                  FieldValue.serverTimestamp(),
                                              'reference_image_count': 0,
                                              'reference_file_count': 0,
                                            });
                                          }

                                          // batch 커밋
                                          await batch.commit();

                                          if (mounted) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                  content: Text(
                                                      '${responseData.length}개의 액션이 생성되었습니다')),
                                            );
                                            // 데이터 새로고침
                                            await _loadData();
                                          }
                                        } else {
                                          print(
                                              '데이터 전송 실패: ${response.statusCode}');
                                          print('에러 응답: ${response.body}');

                                          if (mounted && context.mounted) {
                                            final messenger =
                                                ScaffoldMessenger.of(context);
                                            WidgetsBinding.instance
                                                .addPostFrameCallback((_) {
                                              messenger.hideCurrentSnackBar();
                                              messenger.showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    '서버 오류가 발생했습니다 (${response.statusCode}): ${response.body}',
                                                  ),
                                                  backgroundColor: Colors.red,
                                                  duration: Duration(seconds: 3),
                                                  behavior:
                                                      SnackBarBehavior.floating,
                                                  margin: EdgeInsets.all(16),
                                                ),
                                              );
                                            });
                                          }
                                        }
                                      } catch (e) {
                                        print('AI 생성 로직 오류: $e');
                                        if (mounted && context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('AI 생성 중 오류가 발생했습니다: $e'),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                        }
                                      } finally {
                                        if (mounted) {
                                          setState(() {
                                            _isGeneratingActions = false;  // 생성 완료
                                          });
                                        }
                                      }
                                    },
                                icon: _isGeneratingActions 
                                  ? SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : Icon(Icons.auto_awesome, size: 20),
                                label: Text(_isGeneratingActions ? '생성 중...' : 'AI 상세화'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Theme.of(context).colorScheme.secondary,
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),
                      // Goals List - ReorderableListView를 조건부 변경
                      Expanded(
                        child: ValueListenableBuilder<String?>(
                          valueListenable: expandedGoalId,
                          builder: (context, value, child) {
                            return value == null
                                ? ReorderableListView.builder(
                                    buildDefaultDragHandles: false,
                                    itemCount: goals.length,
                                    onReorder: (oldIndex, newIndex) async {
                                      if (oldIndex < newIndex) {
                                        newIndex -= 1;
                                      }
                                      final item = goals.removeAt(oldIndex);
                                      goals.insert(newIndex, item);

                                      // 같은 timegroup 내에서만 순서 업데이트
                                      final timegroup =
                                          goals[newIndex].timegroup;
                                      final sameTimegroupGoals = goals
                                          .where(
                                              (g) => g.timegroup == timegroup)
                                          .toList();

                                      // Firestore 업데이트
                                      final batch =
                                          FirebaseFirestore.instance.batch();
                                      for (int i = 0;
                                          i < sameTimegroupGoals.length;
                                          i++) {
                                        final docRef = FirebaseFirestore
                                            .instance
                                            .collection('goal_list')
                                            .doc(sameTimegroupGoals[i].id);
                                        batch.update(docRef, {'order': i + 1});
                                      }

                                      try {
                                        await batch.commit();
                                        setState(() {}); // UI 갱신
                                      } catch (e) {
                                        print('Error updating orders: $e');
                                        if (mounted) {
                                          await _loadGoals();
                                        }
                                      }
                                    },
                                    itemBuilder: (context, index) {
                                      return ReorderableDragStartListener(
                                        key: ValueKey(goals[index].id),
                                        index: index,
                                        child: GoalCard(
                                          key: ValueKey(goals[index].id),
                                          goal: goals[index],
                                          isExpanded: goals[index].id == value,
                                          onExpand: (goalId) {
                                            expandedGoalId.value =
                                                expandedGoalId.value == goalId
                                                    ? null
                                                    : goalId;
                                          },
                                        ),
                                      );
                                    },
                                  )
                                : ListView.builder(
                                    itemCount: goals.length,
                                    itemBuilder: (context, index) => GoalCard(
                                      key: ValueKey(goals[index].id),
                                      goal: goals[index],
                                      isExpanded: goals[index].id == value,
                                      onExpand: (goalId) {
                                        expandedGoalId.value =
                                            expandedGoalId.value == goalId
                                                ? null
                                                : goalId;
                                      },
                                    ),
                                  );
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                // Floating Action Button
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: FloatingActionButton(
                    onPressed: _handleGoalAdd,
                    child: Icon(Icons.add),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<int> _getTotalActions() async {
    final snapshot =
        await FirebaseFirestore.instance.collection('action_list').get();
    return snapshot.docs.length;
  }

  Future<int> _getCompletedActions() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('action_list')
        .where('action_status', isEqualTo: 'completed')
        .get();
    return snapshot.docs.length;
  }

  Future<int> _getCompletedGoals() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('goal_list')
        .where('actions', arrayContains: 'completed')
        .get();
    return snapshot.docs.length;
  }

  Future<List<Object>> _getFutureValues() async {
    final totalActions = await _getTotalActions() ?? 0;
    final completedActions = await _getCompletedActions() ?? 0;
    final completedGoals = await _getCompletedGoals() ?? 0;
    final groupTimes = await _getGroupTimes() ?? {};

    final summary = await _calculateSummary();

    return [
      totalActions,
      completedActions,
      completedGoals,
      groupTimes,
      summary
    ];
  }

  Future<Map<String, dynamic>> _calculateSummary() async {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0);

    final actionsSnapshot = await FirebaseFirestore.instance
        .collection('action_list')
        .where('created_at', isGreaterThanOrEqualTo: startOfMonth)
        .where('created_at', isLessThanOrEqualTo: endOfMonth)
        .get();

    double totalPlannedTime = 0;
    double totalExecutedTime = 0;
    int totalPlannedActions = actionsSnapshot.docs.length;
    int completedActions = 0;

    for (var doc in actionsSnapshot.docs) {
      final data = doc.data();
      totalPlannedTime += (data['action_execution_time'] ?? 0).toDouble();

      if (data['action_status'] == 'completed') {
        completedActions++;
        totalExecutedTime += (data['action_execution_time'] ?? 0).toDouble();
      }
    }

    return {
      'totalPlannedTime': totalPlannedTime,
      'totalExecutedTime': totalExecutedTime,
      'totalPlannedActions': totalPlannedActions,
      'completedActions': completedActions,
      'completionRate': totalPlannedActions > 0
          ? (completedActions / totalPlannedActions * 100)
          : 0.0,
      'timeExecutionRate': totalPlannedTime > 0
          ? (totalExecutedTime / totalPlannedTime * 100)
          : 0.0,
    };
  }

  @override
  void dispose() {
    _refreshNotifier.dispose();
    super.dispose();
  }

  Future<double> _calculateRemainingTime(String timegroup) async {
    try {
      final timeslotDocs = await calculateAvailableTimeSlots();

      // 해당 timegroup의 총 남은 시간 계산
      double totalRemainingTime = 0.0;
      final groupPrefix = timegroup.replaceAll('timegroup-', 'group-');

      for (var slot in timeslotDocs) {
        if (slot['subject'] == groupPrefix) {
          final startTime = DateTime.parse(slot['startTime']);
          final endTime = DateTime.parse(slot['endTime']);
          final duration = endTime.difference(startTime).inMinutes / 60.0;
          totalRemainingTime += duration;
        }
      }

      return totalRemainingTime;
    } catch (e) {
      print('Error calculating remaining time: $e');
      return 0.0;
    }
  }

  double _getCreatedActionTime(String timegroup) {
    return goals
        .where((goal) => goal.timegroup == timegroup)
        .expand((goal) => goal.actions)
        .where((action) => action.action_status == 'created')
        .fold(0.0, (sum, action) => sum + action.action_execution_time);
  }

  double _getTotalActionTime(String timegroup) {
    return goals
        .where((goal) => goal.timegroup == timegroup)
        .expand((goal) => goal.actions)
        .fold(0.0, (sum, action) => sum + action.action_execution_time);
  }

  // 각 그룹별 데이터를 구조화하는 함수
  Future<Map<String, Map<String, dynamic>>> prepareGroupData() async {
    final Map<String, Map<String, dynamic>> groupData = {};

    // 각 타임그룹에 대해 데이터 준비
    for (var group in CalendarConstants.timeGroups) {
      // 해당 그룹의 목표들
      final groupGoals = goals.where((g) => g.timegroup == group).toList();

      // 해당 그룹의 액션들
      final groupActions = groupGoals.expand((goal) => goal.actions).toList();

      // 타임슬롯 계산
      final timeslotDocs = await calculateAvailableTimeSlots();
      final groupTimeslots =
          timeslotDocs.where((slot) => slot['subject'] == group).toList();

      // 타임슬롯 요약 계산
      double totalTime = 0;
      double usedTime = 0;
      double remainingTime = 0;

      for (var slot in groupTimeslots) {
        final startTime = DateTime.parse(slot['startTime']);
        final endTime = DateTime.parse(slot['endTime']);
        final duration = endTime.difference(startTime).inMinutes / 60.0;
        totalTime += duration;
      }

      usedTime = groupActions.fold(
          0.0, (sum, action) => sum + action.action_execution_time);
      remainingTime = totalTime - usedTime;

      // 그룹별 데이터 구조화
      groupData[group] = {
        'goals': groupGoals
            .map((g) => {
                  'id': g.id,
                  'name': g.name,
                  'description': g.description,
                  'order': g.order,
                })
            .toList(),
        'actions': groupActions
            .map((a) => {
                  'id': a.id,
                  'name': a.action_name,
                  'description': a.action_description,
                  'execution_time': a.action_execution_time,
                  'status': a.action_status,
                  'order': a.order,
                  'goal_name': a.goal_name,
                })
            .toList(),
        'timeslots': groupTimeslots,
        'summary': {
          'total_time': totalTime,
          'used_time': usedTime,
          'remaining_time': remainingTime,
          'completion_rate': totalTime > 0 ? (usedTime / totalTime * 100) : 0,
        }
      };
    }

    return groupData;
  }

  Future<void> _handleCalendarPlacement() async {
    await newCalendarEvent(context);
  }
}

// Goal Card Widget
class GoalCard extends StatefulWidget {
  final GoalData goal;
  final bool isExpanded; // expand 상 추가
  final Function(String) onExpand; // expand 콜백 가

  const GoalCard({
    required Key key,
    required this.goal,
    required this.isExpanded,
    required this.onExpand,
  }) : super(key: key);

  @override
  State<GoalCard> createState() => _GoalCardState();
}

class _GoalCardState extends State<GoalCard> {
  // Add a reference to the goals list
  List<GoalData> get goals =>
      context.findAncestorStateOfType<_CreateActionState>()?.goals ?? [];

  @override
  Widget build(BuildContext context) {
    final backgroundColor = CalendarConstants
            .timeGroupColors[widget.goal.timegroup]
            ?.withOpacity(0.1) ??
        Colors.grey.withOpacity(0.1);

    final totalExecutionTime = widget.goal.actions
        .fold<double>(0, (sum, action) => sum + action.action_execution_time);

    return Dismissible(
      key: ValueKey(widget.goal.id),
      direction: DismissDirection.endToStart,
      dismissThresholds: const {
        DismissDirection.endToStart: 0.2, // 20%로 제한
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(
          right: MediaQuery.of(context).size.width * 0.1, // 오른쪽에서 10% 패딩
        ),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('삭제 확인'),
            content: Text('정말로 이 목표를 삭제하시겠습니까?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text('예'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('아니요'),
              ),
            ],
          ),
        );
      },
      onDismissed: (direction) async {
        await _deleteGoalAndActions(widget.goal);
        final createActionState =
            context.findAncestorStateOfType<_CreateActionState>();
        if (createActionState != null && createActionState.mounted) {
          createActionState.setState(() {
            createActionState.goals.removeWhere((g) => g.id == widget.goal.id);
          });
        }
      },
      child: Column(
        children: [
          InkWell(
            onTap: () {
              widget.onExpand(widget.goal.id);
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 12, right: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 3,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.goal.name,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Icon(widget.isExpanded
                          ? Icons.expand_less
                          : Icons.expand_more),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(right: 32),
                    child: Text(
                      widget.goal.description.length > 50
                          ? '${widget.goal.description.substring(0, 50)}...'
                          : widget.goal.description,
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        Chip(
                          label: Text(
                            '${CalendarConstants.formatTimeGroup(widget.goal.timegroup)}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.blue[700],
                            ),
                          ),
                          backgroundColor: Colors.blue[50],
                          side: BorderSide(color: Colors.blue[100]!),
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          padding: EdgeInsets.symmetric(horizontal: 4),
                        ),
                        const SizedBox(width: 8),
                        Chip(
                          label: Text(
                            'Actions: ${widget.goal.completedActions}/${widget.goal.totalActions}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.green[700],
                            ),
                          ),
                          backgroundColor: Colors.green[50],
                          side: BorderSide(color: Colors.green[100]!),
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          padding: EdgeInsets.symmetric(horizontal: 4),
                        ),
                        const SizedBox(width: 8),
                        if (widget.goal.totalActions > 0)
                          Chip(
                            label: Text(
                              '${(widget.goal.completedActions / widget.goal.totalActions * 100).toStringAsFixed(0)}%',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.orange[700],
                              ),
                            ),
                            backgroundColor: Colors.orange[50],
                            side: BorderSide(color: Colors.orange[100]!),
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            padding: EdgeInsets.symmetric(horizontal: 4),
                          ),
                        const SizedBox(width: 8),
                        Chip(
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.access_time, size: 14),
                              SizedBox(width: 4),
                              Text(
                                '${totalExecutionTime.toStringAsFixed(1)}H',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.red[700],
                                ),
                              ),
                            ],
                          ),
                          backgroundColor: Colors.red[50],
                          side: BorderSide(color: Colors.red[100]!),
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          padding: EdgeInsets.symmetric(horizontal: 4),
                        ),
                        const SizedBox(width: 8),
                        Chip(
                          label: Text(
                            'Order: ${widget.goal.order}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[700],
                            ),
                          ),
                          backgroundColor: Colors.grey[50],
                          side: BorderSide(color: Colors.grey[200]!),
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          padding: EdgeInsets.symmetric(horizontal: 4),
                        ),
                      ],
                    ),
                  ),
                  if (widget.goal.tags.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: widget.goal.tags
                              .map((tag) => Padding(
                                    padding: const EdgeInsets.only(right: 4),
                                    child: InkWell(
                                      onTap: () => _showTagEditDialog(tag),
                                      child: Chip(
                                        avatar: Icon(Icons.edit, size: 14),
                                        label: Text(
                                          '#$tag',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.blue[700],
                                          ),
                                        ),
                                        backgroundColor: Colors.blue[50],
                                        visualDensity: VisualDensity.compact,
                                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        padding: EdgeInsets.only(left: 0, right: 4),
                                        side: BorderSide(
                                          color: Colors.blue[50]!,
                                          width: 1,
                                        ),
                                      ),
                                    ),
                                  ))
                              .toList(),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (widget.isExpanded) ...[
            const SizedBox(height: 8),
            Container(
              constraints: BoxConstraints(maxHeight: 300),
              child: ReorderableListView.builder(
                shrinkWrap: true,
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: widget.goal.actions.length,
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (oldIndex < newIndex) {
                      newIndex -= 1;
                    }
                    final item = widget.goal.actions.removeAt(oldIndex);
                    widget.goal.actions.insert(newIndex, item);

                    // 순서 업데트
                    for (int i = 0; i < widget.goal.actions.length; i++) {
                      final action = widget.goal.actions[i];
                      FirebaseFirestore.instance
                          .collection('action_list')
                          .doc(action.id)
                          .update({'order': i + 1}).then((_) {
                        // _loadActions(); // 필요 시 호출
                      });
                    }
                  });
                },
                itemBuilder: (context, index) => ActionCard(
                  key: ValueKey(widget.goal.actions[index].id),
                  action: widget.goal.actions[index],
                ),
              ),
            ),
            if (widget.goal.actions.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  '등록된 액션이 없습니다.',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Future<void> _deleteGoalAndActions(GoalData goal) async {
    try {
      // action_list에서 관련 Actions 삭제 전에 reference count 확인
      final actionsSnapshot = await FirebaseFirestore.instance
          .collection('action_list')
          .where('goal_name', isEqualTo: goal.name)
          .get();

      // Google Storage 파일 삭제 처리
      for (var actionDoc in actionsSnapshot.docs) {
        final actionData = actionDoc.data();
        final imageCount = actionData['reference_image_count'] ?? 0;
        final fileCount = actionData['reference_file_count'] ?? 0;

        if (imageCount > 0 || fileCount > 0) {
          await FileStorageUtils.deleteStorageFiles(
            uid: Provider.of<AppState>(context, listen: false).currentUser!.uid,
            goalName: goal.name,
            actionName: actionData['action_name'],
          );
        }
      }
      
      // action_list에서 문서 삭제
      for (var actionDoc in actionsSnapshot.docs) {
        await actionDoc.reference.delete();
      }

      // goal_list에서 Goal 삭제
      await FirebaseFirestore.instance
          .collection('goal_list')
          .doc(goal.id)
          .delete();
      print('Goal ${goal.id} deleted successfully.');

    } catch (e) {
      print('Error deleting goal and actions: $e');
      throw e;
    }
  }

  Future<void> _showTagEditDialog(String currentTag) async {
    final TextEditingController tagController =
        TextEditingController(text: currentTag);

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('태그 수정'),
        content: TextField(
          controller: tagController,
          decoration: InputDecoration(
            labelText: '태그',
            hintText: '태그를 입력하세요',
            prefixText: '#',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, tagController.text.trim()),
            child: Text('저장'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, ''),
            child: Text('삭제'),
          ),
        ],
      ),
    );

    if (result != null) {
      try {
        final goalRef = FirebaseFirestore.instance
            .collection('goal_list')
            .doc(widget.goal.id);

        List<String> updatedTags = List.from(widget.goal.tags);

        if (result.isEmpty) {
          // 태그 삭제
          updatedTags.remove(currentTag);
        } else {
          // 태그 수정
          final index = updatedTags.indexOf(currentTag);
          if (index != -1) {
            updatedTags[index] = result;
          }
        }

        await goalRef.update({'tag': updatedTags});

        // UI 갱신
        final createActionState =
            context.findAncestorStateOfType<_CreateActionState>();
        if (createActionState != null && createActionState.mounted) {
          await createActionState._loadData();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('태그 수정 중 오류가 발생했습니다: $e')),
          );
        }
      }
    }
  }
}

// ActionCard 위젯 추가
class ActionCard extends StatefulWidget {
  final ActionData action;

  const ActionCard({
    required Key key,
    required this.action,
  }) : super(key: key);

  @override
  State<ActionCard> createState() => _ActionCardState();
}

class _ActionCardState extends State<ActionCard> {
  bool isEditing = false;
  late TextEditingController nameController;
  late TextEditingController descriptionController;
  late TextEditingController timeController;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  void _initControllers() {
    if (!_isDisposed) {
      nameController = TextEditingController(text: widget.action.action_name);
      descriptionController =
          TextEditingController(text: widget.action.action_description);
      timeController = TextEditingController(
          text: widget.action.action_execution_time.toStringAsFixed(1));
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    if (mounted) {
      nameController.dispose();
      descriptionController.dispose();
      timeController.dispose();
    }
    super.dispose();
  }

  @override
  void didUpdateWidget(ActionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.action != widget.action && !_isDisposed) {
      nameController.text = widget.action.action_name;
      descriptionController.text = widget.action.action_description;
      timeController.text =
          widget.action.action_execution_time.toStringAsFixed(1);
    }
  }

  Future<void> _saveChanges() async {
    if (_isDisposed) return;

    try {
      final executionTime = double.tryParse(timeController.text) ?? 0.0;

      await FirebaseFirestore.instance
          .collection('action_list')
          .doc(widget.action.id)
          .update({
        'action_name': nameController.text,
        'action_description': descriptionController.text,
        'action_execution_time': executionTime,
      });

      // 먼저 편집 모드를 종료
      if (!_isDisposed) {
        setState(() {
          isEditing = false;
        });
      }

      // 상위 상태 업데이트를 다음 프레임으로 지연
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final createActionState =
            context.findAncestorStateOfType<_CreateActionState>();
        if (createActionState != null && createActionState.mounted) {
          createActionState._loadData().then((_) {
            if (createActionState.mounted) {
              createActionState._refreshNotifier.value =
                  !createActionState._refreshNotifier.value;
            }
          });
        }
      });
    } catch (e) {
      print('Error saving changes: $e');
      if (!_isDisposed && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('변경사항 저장 중 오류가 발생했습니다: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    String formatTime(int time) {
      return '${time.toStringAsFixed(1)}시간';
    }

    return Container(
      margin: const EdgeInsets.only(left: 16, bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey[200]!),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            spreadRadius: 0,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: isEditing
                    ? SizedBox(
                        width: MediaQuery.of(context).size.width * 0.6,
                        child: TextField(
                          controller: nameController,
                          style: TextStyle(fontSize: 14),
                          decoration: InputDecoration(
                            labelText: '액션 이름',
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                                vertical: 8, horizontal: 8),
                          ),
                        ),
                      )
                    : Text(
                        widget.action.action_name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
              IconButton(
                icon: Icon(isEditing ? Icons.save : Icons.edit),
                onPressed: () {
                  if (isEditing) {
                    _saveChanges();
                  } else {
                    setState(() {
                      isEditing = true;
                    });
                  }
                },
              ),
              IconButton(
                icon: Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () => _showDeleteConfirmation(context),
              ),
            ],
          ),
          const SizedBox(height: 4),
          isEditing
              ? TextField(
                  controller: descriptionController,
                  style: TextStyle(fontSize: 12),
                  decoration: InputDecoration(
                    labelText: '설명',
                    contentPadding: EdgeInsets.only(
                      top: 8,
                      bottom: 8,
                      left: 8,
                      right: 40,
                    ),
                  ),
                )
              : Padding(
                  padding: EdgeInsets.only(right: 40),
                  child: Text(
                    widget.action.action_description,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
          const SizedBox(height: 8),
          Row(
            children: [
              Chip(
                label: Text(
                  'Order: ${widget.action.order}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[700],
                  ),
                ),
                backgroundColor: Colors.grey[50],
                side: BorderSide(color: Colors.grey[200]!),
                labelStyle: TextStyle(color: Colors.grey[700]),
              ),
              const SizedBox(width: 8),
              Chip(
                label: Text(
                  widget.action.action_status,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.green[700],
                  ),
                ),
                backgroundColor: Colors.green[50],
                side: BorderSide(color: Colors.green[100]!),
                labelStyle: TextStyle(color: Colors.green[700]),
              ),
              const SizedBox(width: 8),
              if (!isEditing)
                Chip(
                  label: Text(
                    '${widget.action.action_execution_time.toStringAsFixed(1)}H',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.blue[700],
                    ),
                  ),
                  backgroundColor: Colors.blue[50],
                  side: BorderSide(color: Colors.blue[100]!),
                  labelStyle: TextStyle(color: Colors.blue[700]),
                )
              else
                Expanded(
                  child: Container(
                    constraints: BoxConstraints(maxWidth: 100),
                    child: TextField(
                      controller: timeController,
                      style: TextStyle(fontSize: 14),
                      decoration: InputDecoration(
                        labelText: '실행 시간',
                        isDense: true,
                        contentPadding:
                            EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                      ),
                      keyboardType:
                          TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // 삭제 인 다이얼로그를 보여주는 메서드
  Future<void> _showDeleteConfirmation(BuildContext context) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('액션 삭제'),
        content: Text('이 액션을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              '삭제',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      await _deleteAction();
    }
  }

  // 액션을 삭제하는 메서드
  Future<void> _deleteAction() async {
    try {
      // 액션 데이터 가져오기
      final actionDoc = await FirebaseFirestore.instance
          .collection('action_list')
          .doc(widget.action.id)
          .get();
      
      final actionData = actionDoc.data();
      if (actionData != null) {
        // Storage 파일 삭제 처리
        final imageCount = actionData['reference_image_count'] ?? 0;
        final fileCount = actionData['reference_file_count'] ?? 0;

        if (imageCount > 0 || fileCount > 0) {
          await FileStorageUtils.deleteStorageFiles(
            uid: Provider.of<AppState>(context, listen: false).currentUser!.uid,
            goalName: widget.action.goal_name,
            actionName: widget.action.action_name,
          );
        }

        // action_history에서 관련 기록 삭제
        final historySnapshot = await FirebaseFirestore.instance
            .collection('action_history')
            .where('action_name', isEqualTo: widget.action.action_name)
            .get();

        // 일괄 삭제를 위한 batch 작성
        final batch = FirebaseFirestore.instance.batch();
        
        // action_history 문서들 삭제
        for (var doc in historySnapshot.docs) {
          batch.delete(doc.reference);
        }
        
        // action_list에서 액션 문서 삭제
        batch.delete(FirebaseFirestore.instance
            .collection('action_list')
            .doc(widget.action.id));

        // batch 실행
        await batch.commit();
      }

      // 상위 위젯의 상태를 갱신
      final createActionState = context.findAncestorStateOfType<_CreateActionState>();
      if (createActionState != null && createActionState.mounted) {
        await createActionState._loadData();
      }

      if (!_isDisposed && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('액션이 삭제되었습니다')),
        );
      }
    } catch (e) {
      if (!_isDisposed && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('액션 삭제 중 오류가 발생했습니다: $e')),
        );
      }
    }
  }
}

// ActionButton Widget 추가
class ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 8),
            Text(label),
          ],
        ),
      ),
    );
  }
}


// GoalData 모델 클래스 수정
class GoalData {
  final String id;
  final String name;
  final String description;
  final String timegroup;
  final int order;
  final Timestamp created_at;
  final List<ActionData> actions;
  final int completedActions;
  final int totalActions;
  final List<String> tags;
  final String uid;

  GoalData({
    required this.id,
    required this.name,
    required this.description,
    required this.timegroup,
    required this.order,
    required this.created_at,
    this.actions = const [],
    this.completedActions = 0,
    this.totalActions = 0,
    this.tags = const [],
    required this.uid,
  });

  static Future<GoalData> fromDocument(DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;
    final actions = await _getActionsForGoal(doc.id, data['name'] ?? '');
    final completedActions =
        actions.where((action) => action.action_status == 'completed').length;
    final totalActions = actions.length;
    final tagData = data['tag'] ?? [];
    final tags = (tagData as List).map((tag) => tag.toString()).toList();

    return GoalData(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      timegroup: data['timegroup'] ?? '',
      order: data['order'] ?? 0,
      created_at: data['created_at'] ?? Timestamp.now(),
      actions: actions,
      completedActions: completedActions,
      totalActions: totalActions,
      tags: tags,
      uid: data['uid'] ?? '',
    );
  }

  // 특정 목에 속한 액션들을 로드하는 메서드
  static Future<List<ActionData>> _getActionsForGoal(
      String goalId, String goalName) async {
    // goal_name으로 필터링하여 액션 목록 조회
    final snapshot = await FirebaseFirestore.instance
        .collection('action_list')
        .where('goal_name', isEqualTo: goalName)
        .get();

    // 액션들을 order 기준으로 정렬
    final actions =
        snapshot.docs.map((doc) => ActionData.fromDocument(doc)).toList();
    actions.sort((a, b) => a.order.compareTo(b.order));

    return actions;
  }
}

// ActionData 델 클래스 추가
class ActionData {
  final String id;
  final String action_name;
  final String action_description;
  final String action_status;
  final int order;
  final String goal_name;
  final double action_execution_time;
  final int reference_image_count;
  final int reference_file_count;

  ActionData({
    required this.id,
    required this.action_name,
    required this.action_description,
    required this.action_status,
    required this.order,
    required this.goal_name,
    required this.action_execution_time,
    this.reference_image_count = 0,
    this.reference_file_count = 0,
  });

  factory ActionData.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ActionData(
      id: doc.id,
      action_name: data['action_name'] ?? '',
      action_description: data['action_description'] ?? '',
      action_status: data['action_status'] ?? '',
      order: data['order'] ?? 0,
      goal_name: data['goal_name'] ?? '',
      action_execution_time: (data['action_execution_time'] is int)
          ? (data['action_execution_time'] as int).toDouble()
          : (data['action_execution_time'] as double?) ?? 0.0,
      reference_image_count: data['reference_image_count'] ?? 0,
      reference_file_count: data['reference_file_count'] ?? 0,
    );
  }
}

// 진행률 표시 위젯 헬퍼 메소드 추가
Widget _buildProgressIndicator(
  String label,
  int completed,
  int total,
  Color color,
) {
  final percentage = total > 0 ? (completed / total * 100) : 0.0;

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(
            '$completed/$total',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
      const SizedBox(height: 4),
      Stack(
        children: [
          LinearProgressIndicator(
            value: percentage / 100,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 8,
          ),
          Positioned.fill(
            child: Center(
              child: Text(
                '${percentage.toStringAsFixed(1)}%',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    ],
  );
}

// 새로운 메소드 추가
Future<List<Map<String, dynamic>>> calculateAvailableTimeSlots({
  DateTime? startTime,
  DateTime? endTime,
}) async {
  try {
    startTime ??= DateTime.now();
    endTime ??= DateTime(startTime.year, startTime.month + 1, 0, 23, 59, 59);

    double totalOriginalTime = 0;
    double totalEventTime = 0;

    // 본 timeslot 가오기
    final timeslotSnapshot = await FirebaseFirestore.instance
        .collection('timeslot')
        .where('startTime',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startTime))
            .where('startTime', isLessThanOrEqualTo: Timestamp.fromDate(endTime))
            .get();

    final timeslotDocs = timeslotSnapshot.docs.map((doc) {
      final data = doc.data();
      final start = (data['startTime'] as Timestamp).toDate();
      final end = (data['endTime'] as Timestamp).toDate();
      totalOriginalTime += end.difference(start).inMinutes / 60;

      data['startTime'] = start.toIso8601String();
      data['endTime'] = end.toIso8601String();
      return data;
    }).toList();

    // timeslot_event 처리
    final eventSnapshot = await FirebaseFirestore.instance
        .collection('timeslot_event')
        .where('startTime',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startTime))
        .where('startTime', isLessThanOrEqualTo: Timestamp.fromDate(endTime))
        .get();

    // print('\n=== 이벤트 처리 시작 ===');
    // print('처리할 이벤트 수: ${eventSnapshot.docs.length}');

    for (var doc in eventSnapshot.docs) {
      final eventData = doc.data();
      final type = eventData['type'] as String?;
      final eventStart = (eventData['startTime'] as Timestamp).toDate();
      final eventEnd = (eventData['endTime'] as Timestamp).toDate();
      final eventDuration = eventEnd.difference(eventStart).inMinutes / 60;
      final subject = eventData['subject'] as String?;

      // print('\n이벤트 처리:');
      // print('타입: $type');
      // print('시작: $eventStart');
      // print('종료: $eventEnd');
      // print('과목: $subject');
      // print('시간: ${eventDuration.toStringAsFixed(1)}H');
      if (type == 'add') {
        timeslotDocs.add({
          'startTime': eventStart.toIso8601String(),
          'endTime': eventEnd.toIso8601String(),
          'subject': subject?.replaceAll('event-', 'group-'),
        });
        totalEventTime += eventDuration;
        print('이벤트 추가 완료: +${eventDuration.toStringAsFixed(1)}H');
      } else if (type == 'sub') {
        totalEventTime -= eventDuration;
        // print('이벤트 차감 [${subject ?? 'Unknown'}]: -${eventDuration.toStringAsFixed(1)}H');
        for (var i = 0; i < timeslotDocs.length; i++) {
          final slot = timeslotDocs[i];
          final slotStart = DateTime.parse(slot['startTime']);
          final slotEnd = DateTime.parse(slot['endTime']);

          if (eventStart.isBefore(slotEnd) && eventEnd.isAfter(slotStart)) {
            if (eventStart.isAfter(slotStart) && eventEnd.isBefore(slotEnd)) {
              // 원래 타임슬롯의 subject를 유지
              final originalSubject = timeslotDocs[i]['subject'];
              timeslotDocs[i] = {
                'startTime': slotStart.toIso8601String(),
                'endTime': eventStart.toIso8601String(),
                'subject': originalSubject, // 원래 subject 유지
              };
              timeslotDocs.add({
                'startTime': eventEnd.toIso8601String(),
                'endTime': slotEnd.toIso8601String(),
                'subject': originalSubject, // 원래 subject 유지
              });
            } else if (eventStart.isAfter(slotStart)) {
              timeslotDocs[i]['endTime'] = eventStart.toIso8601String();
            } else if (eventEnd.isBefore(slotEnd)) {
              timeslotDocs[i]['startTime'] = eventEnd.toIso8601String();
            }
          }
        }
      }
    }

    // subject별 시간 집계를 위한 Map 추가
    Map<String, double> timeBySubject = {};

    // 기본 타임슬롯의 subject별 시간 계산
    for (var slot in timeslotDocs) {
      final subject = slot['subject'] as String? ?? 'undefined';
      final start = DateTime.parse(slot['startTime']);
      final end = DateTime.parse(slot['endTime']);
      final duration = end.difference(start).inMinutes / 60;
      timeBySubject[subject] = (timeBySubject[subject] ?? 0) + duration;
    }

    final remainingTotalTime = totalOriginalTime + totalEventTime;
    // print('\n=== 타임슬롯 계산 결과 ===');
    // print('기본 타임슬롯 총 시간: ${totalOriginalTime.toStringAsFixed(1)}H');
    // print('이벤트로 인한 시간 변동: ${totalEventTime.toStringAsFixed(1)}H');
    // print('최종 가용 시간: ${remainingTotalTime.toStringAsFixed(1)}H');
    // print('최종 타임슬롯 개수: ${timeslotDocs.length}개\n');

    // print('=== Subject별 시간 분포 ===');
    timeBySubject.forEach((subject, time) {
      print(
          '$subject: ${time.toStringAsFixed(1)}H (${(time / remainingTotalTime * 100).toStringAsFixed(1)}%)');
    });

    return timeslotDocs;
  } catch (e) {
    print('Error calculating available time slots: $e');
    return [];
  }
}

// _calculateRemainingTime 메서드 대신 새로운 메서드 추가
Future<Map<String, double>> _calculateAllRemainingTimes() async {
  try {
    final timeslotDocs = await calculateAvailableTimeSlots();
    final remainingTimes = <String, double>{};

    // 각 타임그룹의 기본값을 0.0으로 초기화
    for (var group in CalendarConstants.timeGroups) {
      remainingTimes[group] = 0.0;
    }

    // 모든 타임슬롯에 대해 한 번만 순회하면서 각 그룹의 남은 시간 계산
    for (var slot in timeslotDocs) {
      final subject = slot['subject'] as String?;
      if (subject != null) {
        final timegroup = subject;
        if (remainingTimes.containsKey(timegroup)) {
          final startTime = DateTime.parse(slot['startTime']);
          final endTime = DateTime.parse(slot['endTime']);
          final duration = endTime.difference(startTime).inMinutes / 60.0;
          final previousTime = remainingTimes[timegroup] ?? 0.0;
          remainingTimes[timegroup] = previousTime + duration;
        }
      }
    }

    return remainingTimes;
  } catch (e) {
    print('Error calculating remaining times: $e');
    return {};
  }
}