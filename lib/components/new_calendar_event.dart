import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';

Future<void> newCalendarEvent(BuildContext context) async {
  try {
    print('\n=== 캘린더 배치 시작 ===');

    // 1. completed가 아닌 calendar_event 문서들만 삭제
    final existingEvents = await FirebaseFirestore.instance
        .collection('calendar_event')
        .where('action_status', isNotEqualTo: 'completed')
        .get();

    final batch = FirebaseFirestore.instance.batch();
    for (var doc in existingEvents.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();

    // 2. 정렬된 goals와 actions 준비
    final goalsSnapshot =
        await FirebaseFirestore.instance.collection('goal_list').get();
    final goals = await Future.wait(
        goalsSnapshot.docs.map((doc) => GoalData.fromDocument(doc)));

    final sortedGoals = List<GoalData>.from(goals)
      ..sort((a, b) {
        // 1. 먼저 timegroup으로 정렬
        final timeGroupComparison = a.timegroup.compareTo(b.timegroup);
        if (timeGroupComparison != 0) return timeGroupComparison;
        // 2. 같은 timegroup 내에서는 order의 역순으로 정렬 (b.order.compareTo(a.order))
        return a.order.compareTo(b.order);
      });

    // completed가 아닌 액션만 필터링
    final allActions = sortedGoals
        .expand((goal) => goal.actions
            .where((action) => action.action_status != 'completed')
            .map((action) => {
                  'timegroup': goal.timegroup,
                  'id': action.id,
                  'action_name': action.action_name,
                  'action_description': action.action_description,
                  'action_status': action.action_status,
                  'order': action.order,
                  'goal_name': action.goal_name,
                  'goal_order': goal.order,
                  'action_execution_time': action.action_execution_time,
                  'tags': goal.tags,
                }))
        .toList()
      ..sort((a, b) {
        // 1. timegroup으로 정렬
        final timeGroupComparison =
            (a['timegroup'] as String).compareTo(b['timegroup'] as String);
        if (timeGroupComparison != 0) return timeGroupComparison;

        // 2. goal_order로 정렬
        final goalOrderComparison =
            (a['goal_order'] as int).compareTo(b['goal_order'] as int);
        if (goalOrderComparison != 0) return goalOrderComparison;

        // 3. action의 order로 정렬
        return (a['order'] as int).compareTo(b['order'] as int);
      });

    print('\n전체 액션 수: ${allActions.length}');

    // 3. 사용 가능한 타임슬롯 계산
    final timeslotDocs = await calculateAvailableTimeSlots();
    print('사용 가능한 타임슬롯 수: ${timeslotDocs.length}');

    // Firestore batch 생성
    final newBatch = FirebaseFirestore.instance.batch();
    int placedActions = 0;

    // 캘린더 이벤트를 임시 저장할 리스트
    List<Map<String, dynamic>> tempCalendarEvents = [];

    // 각 timegroup별로 처리
    for (var timegroup in ['group-1', 'group-2', 'group-3', 'group-4']) {
      print('\n=== $timegroup 처리 중 ===');

      final groupActions = allActions
          .where((action) => action['timegroup'] == timegroup)
          .toList();
      print('$timegroup의 액션 수: ${groupActions.length}');

      final groupSlots =
          timeslotDocs.where((slot) => slot['subject'] == timegroup).toList();
      print('$timegroup의 사용 가능한 슬롯 수: ${groupSlots.length}');

      int currentSlotIndex = 0;

      // 각 action을 적절한 슬롯에 배치
      for (var action in groupActions) {
        double remainingActionTime = action['action_execution_time'] as double;
        final actionName = action['action_name'] as String;

        while (
            remainingActionTime > 0 && currentSlotIndex < groupSlots.length) {
          final slot = groupSlots[currentSlotIndex];
          final slotStart = DateTime.parse(slot['startTime']);
          final slotEnd = DateTime.parse(slot['endTime']);

          final availableDuration =
              slotEnd.difference(slotStart).inMinutes / 60.0;

          if (availableDuration > 0) {
            final allocatedTime = min(remainingActionTime, availableDuration);
            final eventEnd =
                slotStart.add(Duration(minutes: (allocatedTime * 60).round()));

            // 이벤트 데이터를 임시 리스트에 저장
            tempCalendarEvents.add({
              'startTime': slotStart,
              'endTime': eventEnd,
              'action_name': action['action_name'],
              'action_status': 'scheduled',
              'action_id': action['id'],
              'action_execution_time': allocatedTime,
              'original_execution_time': action['action_execution_time'],
              'goal_name': action['goal_name'],
              'goal_order': action['goal_order'],
              'action_order': action['order'],
              'timegroup': action['timegroup'],
              'reminder_minutes': 30,
              'reminder_enabled': false,
              'reminder_timestamp': slotStart.subtract(Duration(minutes: 30)),
              'goal_tag': action['tags'],
            });

            placedActions++;

            remainingActionTime -= allocatedTime;

            if (availableDuration > allocatedTime) {
              groupSlots[currentSlotIndex] = {
                ...slot,
                'startTime': eventEnd.toIso8601String(),
              };
            } else {
              currentSlotIndex++;
            }
          } else {
            currentSlotIndex++;
          }
        }

        if (remainingActionTime > 0) {
          print(
              '경고: ${action['action_name']}의 ${remainingActionTime}H를 배치하지 못했습니다.');
        }
      }
    }

    // action_split_count와 action_split_num 계산
    Map<String, List<Map<String, dynamic>>> eventsByActionName = {};
    for (var event in tempCalendarEvents) {
      final actionName = event['action_name'] as String;
      eventsByActionName.putIfAbsent(actionName, () => []).add(event);
    }

    // 각 action_name 그룹별로 정렬하고 split 정보 추가
    for (var actionName in eventsByActionName.keys) {
      var events = eventsByActionName[actionName]!;
      // startTime을 기준으로 정렬
      events.sort((a, b) =>
          (a['startTime'] as DateTime).compareTo(b['startTime'] as DateTime));

      final splitCount = events.length;
      for (var i = 0; i < events.length; i++) {
        final eventRef =
            FirebaseFirestore.instance.collection('calendar_event').doc();
        newBatch.set(eventRef, {
          ...events[i],
          'startTime': Timestamp.fromDate(events[i]['startTime'] as DateTime),
          'endTime': Timestamp.fromDate(events[i]['endTime'] as DateTime),
          'reminder_timestamp':
              Timestamp.fromDate(events[i]['reminder_timestamp'] as DateTime),
          'action_split_count': splitCount,
          'action_split_num': i + 1,
        });
      }
    }

    // Batch 커밋
    await newBatch.commit();
    print('\n=== 캘린더 배치 완료 ===');
    print('총 배치된 액션 수: $placedActions');
  } catch (e) {
    print('Calendar placement error: $e');
  }
}

// 필요한 헬퍼 함수들
Future<List<Map<String, dynamic>>> calculateAvailableTimeSlots({
  DateTime? startTime,
  DateTime? endTime,
}) async {
  try {
    // 시작 시간을 현재 시간으로 설정
    startTime = DateTime.now();

    // 종료 시간을 현재 달의 마지막 날 23:59:59로 설정
    endTime = DateTime(
      startTime.year,
      startTime.month + 1,
      0,
      23,
      59,
      59,
    );

    // 시간 계산을 위한 변수 초기화
    double totalOriginalTime = 0.0;
    double totalEventTime = 0.0;

    // Firestore 쿼리 수정
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
      return {
        'startTime': start.toIso8601String(),
        'endTime': end.toIso8601String(),
        'subject': data['subject'],
      };
    }).toList();

    // timeslot_event 처리
    final eventSnapshot = await FirebaseFirestore.instance
        .collection('timeslot_event')
        .where('startTime',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startTime))
        .where('startTime', isLessThanOrEqualTo: Timestamp.fromDate(endTime))
        .get();

    print('\n=== 이벤트 처리 시작 ===');
    print('처리할 이벤트 수: ${eventSnapshot.docs.length}');

    for (var doc in eventSnapshot.docs) {
      final eventData = doc.data();
      final type = eventData['type'] as String?;
      final eventStart = (eventData['startTime'] as Timestamp).toDate();
      final eventEnd = (eventData['endTime'] as Timestamp).toDate();
      final eventDuration = eventEnd.difference(eventStart).inMinutes / 60;
      final subject = eventData['subject'] as String?;

      print('\n이벤트 처리:');
      print('타입: $type');
      print('시작: $eventStart');
      print('종료: $eventEnd');
      print('과목: $subject');
      print('시간: ${eventDuration.toStringAsFixed(1)}H');

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
                'subject': originalSubject,
              };
              timeslotDocs.add({
                'startTime': eventEnd.toIso8601String(),
                'endTime': slotEnd.toIso8601String(),
                'subject': originalSubject,
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

    // subject별 시간 집계
    Map<String, double> timeBySubject = {};
    for (var slot in timeslotDocs) {
      final subject = slot['subject'] as String? ?? 'undefined';
      final start = DateTime.parse(slot['startTime']);
      final end = DateTime.parse(slot['endTime']);
      final duration = end.difference(start).inMinutes / 60;
      timeBySubject[subject] = (timeBySubject[subject] ?? 0) + duration;
    }

    final remainingTotalTime = totalOriginalTime + totalEventTime;
    print('\n=== 타임슬롯 계산 결과 ===');
    print('기본 타임슬롯 총 시간: ${totalOriginalTime.toStringAsFixed(1)}H');
    print('이벤트로 인한 시간 변동: ${totalEventTime.toStringAsFixed(1)}H');
    print('최종 가용 시간: ${remainingTotalTime.toStringAsFixed(1)}H');
    print('최종 타임슬롯 개수: ${timeslotDocs.length}개\n');

    print('=== Subject별 시간 분포 ===');
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

// GoalData 모델 클래스 추가
class GoalData {
  final String id;
  final String name;
  final String description;
  final String timegroup;
  final int order;
  final Timestamp created_at;
  final List<ActionData> actions;
  final List<String> tags;

  GoalData({
    required this.id,
    required this.name,
    required this.description,
    required this.timegroup,
    required this.order,
    required this.created_at,
    this.actions = const [],
    this.tags = const [],
  });

  static Future<GoalData> fromDocument(DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;
    final actions = await _getActionsForGoal(doc.id, data['name'] ?? '');

    List<String> tags = [];
    if (data['tag'] != null) {
      tags = List<String>.from(data['tag']);
    }

    return GoalData(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      timegroup: data['timegroup'] ?? '',
      order: data['order'] ?? 0,
      created_at: data['created_at'] ?? Timestamp.now(),
      actions: actions,
      tags: tags,
    );
  }

  static Future<List<ActionData>> _getActionsForGoal(
      String goalId, String goalName) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('action_list')
        .where('goal_name', isEqualTo: goalName)
        .get();

    final actions =
        snapshot.docs.map((doc) => ActionData.fromDocument(doc)).toList();
    actions.sort((a, b) => a.order.compareTo(b.order));

    return actions;
  }
}

// ActionData 모델 클래스 추가
class ActionData {
  final String id;
  final String action_name;
  final String action_description;
  final String action_status;
  final int order;
  final String goal_name;
  final double action_execution_time;

  ActionData({
    required this.id,
    required this.action_name,
    required this.action_description,
    required this.action_status,
    required this.order,
    required this.goal_name,
    required this.action_execution_time,
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
    );
  }
}
