import 'dart:math' ;
import 'package:flutter/gestures.dart'; // 추가
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';

// 추가 패키지 임포트
import 'package:logger/logger.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:syncfusion_flutter_sliders/sliders.dart';

// 상수 정의
class CalendarConstants {
  static const int startHour = 6;
  static const int endHour = 23;
  static const Duration timeSlotDuration = Duration(minutes: 30);

  static const timeGroups = [
    'group-1',
    'group-2',
    'group-3',
    'group-4',
  ];

  static const timegroup_event = [
    'event-1',
    'event-2',
    'event-3',
    'event-4',
  ];

  static final timeGroupColors = {
    'group-1': const Color(0xFF6366F1),
    'group-2': const Color(0xFFEC4899),
    'group-3': const Color(0xFF14B8A6),
    'group-4': const Color(0xFFF59E0B),
  };

  static final timeGroupEventColors = {
    'event-1': const Color(0xFF818CF8),
    'event-2': const Color(0xFFF472B6),
    'event-3': const Color(0xFF2DD4BF),
    'event-4': const Color(0xFFFBBF24),
  };
}

// 기존 Meeting 클래스를 추상 클래스로 변경
abstract class BaseMeeting {
  BaseMeeting(this.subject, this.startTime, this.endTime, this.background,
      this.isAllDay);

  String subject;
  DateTime startTime;
  DateTime endTime;
  Color background;
  bool isAllDay;
}

// Group 타임슬롯을 위한 클래스
class GroupMeeting extends BaseMeeting {
  GroupMeeting(
    String subject,
    DateTime startTime,
    DateTime endTime,
    Color background,
    bool isAllDay,
  ) : super(subject, startTime, endTime, background, isAllDay);
}

// Event 타임슬롯을 위한 클래스
class EventMeeting extends BaseMeeting {
  EventMeeting(
    String subject,
    DateTime startTime,
    DateTime endTime,
    Color background,
    bool isAllDay,
    this.type,
  ) : super(subject, startTime, endTime, background, isAllDay);

  String type; // 'add'  'sub'
}

// MeetingDataSource 클스 수정
class MeetingDataSource extends CalendarDataSource {
  MeetingDataSource(List<BaseMeeting> source) {
    appointments = source;
  }

  @override
  DateTime getStartTime(int index) => appointments![index].startTime;

  @override
  DateTime getEndTime(int index) => appointments![index].endTime;

  @override
  String getSubject(int index) => appointments![index].subject;

  @override
  Color getColor(int index) => appointments![index].background;

  @override
  bool isAllDay(int index) => appointments![index].isAllDay;
}

// 메인 위젯
class AddTimeslotEventCalendar extends StatefulWidget {
  const AddTimeslotEventCalendar({
    super.key,
    this.width,
    this.height,
  });

  final double? width;
  final double? height;

  @override
  State<AddTimeslotEventCalendar> createState() =>
      _AddTimeslotEventCalendarState();
}

class _AddTimeslotEventCalendarState extends State<AddTimeslotEventCalendar> {
  final _firestore = FirebaseFirestore.instance;
  List<BaseMeeting> meetings = [];
  late MeetingDataSource _meetingDataSource;
  final _logger = Logger();
  bool _isDisposed = false;
  String selectedTimeGroup = CalendarConstants.timeGroups[0];
  String existingGroup = '';
  late TimeOfDay selectedEndTime;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _isDisposed = false;
    _initializeCalendar();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _isDisposed = true;
    super.dispose();
  }

  Future<void> _initializeCalendar() async {
    meetings = [];
    _meetingDataSource = MeetingDataSource(meetings);
    if (!_isDisposed) {
      await _loadEventsFromFirestore();
    }
  }

  @override
  void setState(VoidCallback fn) {
    if (mounted) {
      super.setState(fn);
    }
  }

  Future<void> _loadEventsFromFirestore() async {
    if (!mounted) return;

    try {
      final now = DateTime.now();
      final monthStart = DateTime(now.year, now.month, 1);
      final monthEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

      final List<BaseMeeting> loadedMeetings = [];

      // timeslot 컬렉션 읽기
      if (!mounted) return;
      final timeslotSnapshot = await _firestore
          .collection('timeslot')
          .where('startTime',
              isGreaterThanOrEqualTo: Timestamp.fromDate(monthStart))
          .where('startTime', isLessThanOrEqualTo: Timestamp.fromDate(monthEnd))
          .get();

      if (!mounted) return;

      // timeslot_event 컬렉션 읽기
      final eventSnapshot = await _firestore
          .collection('timeslot_event')
          .where('startTime',
              isGreaterThanOrEqualTo: Timestamp.fromDate(monthStart))
          .where('startTime', isLessThanOrEqualTo: Timestamp.fromDate(monthEnd))
          .get();

      if (!mounted) return;

      // timeslot 데이터 처리
      for (var doc in timeslotSnapshot.docs) {
        if (!mounted) return;
        final data = doc.data();
        final startTime = (data['startTime'] as Timestamp).toDate();
        final endTime = (data['endTime'] as Timestamp).toDate();
        final subject = data['subject'] as String;

        final background =
            CalendarConstants.timeGroupColors[subject] ?? Colors.grey;

        loadedMeetings.add(GroupMeeting(
          subject,
          startTime,
          endTime,
          background,
          false,
        ));
      }

      // timeslot_event 데이터 처리
      for (var doc in eventSnapshot.docs) {
        if (!mounted) return;
        final data = doc.data();
        final startTime = (data['startTime'] as Timestamp).toDate();
        final endTime = (data['endTime'] as Timestamp).toDate();
        final subject = data['subject'] as String;
        final type = data['type'] as String;

        final background =
            CalendarConstants.timeGroupEventColors[subject] ?? Colors.grey;

        loadedMeetings.add(EventMeeting(
          subject,
          startTime,
          endTime,
          background,
          false,
          type,
        ));
      }

      if (!mounted) return;

      setState(() {
        meetings = loadedMeetings;
        _meetingDataSource = MeetingDataSource(meetings);
      });
    } catch (e) {
      if (mounted) {
        _logger.e('Failed to load events from Firestore: $e');
      }
    }
  }

  // 현재 주의 시작일과 종료일을 계산하는 함수
  (DateTime, DateTime) _getCurrentWeekRange() {
    final now = DateTime.now();
    final firstDayOfWeek = now.subtract(Duration(days: now.weekday % 7));
    final lastDayOfWeek = firstDayOfWeek.add(const Duration(days: 6));

    return (
      DateTime(firstDayOfWeek.year, firstDayOfWeek.month, firstDayOfWeek.day),
      DateTime(lastDayOfWeek.year, lastDayOfWeek.month, lastDayOfWeek.day, 23,
          59, 59)
    );
  }

  @override
  Widget build(BuildContext context) {
    final (weekStart, weekEnd) = _getCurrentWeekRange();

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          constraints: const BoxConstraints(maxHeight: 300),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: FutureBuilder(
              future: _buildTimeSlotSummary(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                return snapshot.data ?? Container();
              },
            ),
          ),
        ),
        Expanded(
          child: SfCalendar(
            view: CalendarView.week,
            firstDayOfWeek: 7,
            minDate: weekStart,
            maxDate: weekEnd,
            timeSlotViewSettings: TimeSlotViewSettings(
              startHour: 0,
              endHour: 24,
              timeFormat: 'HH:mm',
              timeIntervalHeight: 30,
              timeInterval: CalendarConstants.timeSlotDuration,
            ),
            initialDisplayDate: DateTime(
              DateTime.now().year,
              DateTime.now().month,
              DateTime.now().day,
              9,
            ),
            dataSource: _meetingDataSource,
            onTap: (CalendarTapDetails details) {
              if (details.targetElement == CalendarElement.calendarCell) {
                _showAddEventDialog(details.date!);
              }
            },
            onLongPress: (CalendarLongPressDetails details) {
              if (details.targetElement == CalendarElement.appointment) {
                final BaseMeeting? tappedMeeting = meetings.firstWhere(
                  (m) =>
                      details.date!.isAfter(
                          m.startTime.subtract(const Duration(minutes: 1))) &&
                      details.date!.isBefore(
                          m.endTime.add(const Duration(minutes: 1))) &&
                      details.appointments?.first.subject == m.subject,
                  orElse: () => meetings[0],
                );

                if (tappedMeeting != null) {
                  _showDeleteEventDialog(tappedMeeting);
                }
              }
            },
            appointmentBuilder: (context, calendarAppointmentDetails) {
              final appointment = calendarAppointmentDetails.appointments.first;
              final meeting = meetings.firstWhere(
                (m) =>
                    m.startTime == appointment.startTime &&
                    m.endTime == appointment.endTime,
                orElse: () => meetings[0],
              );

              return Container(
                decoration: BoxDecoration(
                  color: meeting.background.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(4),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  meeting.subject,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<Widget> _buildTimeSlotSummary() async {
    final now = DateTime.now();

    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    Map<String, Map<String, Duration>> timeGroupDurations = {};
    Map<String, Map<String, Duration>> eventGroupDurations = {};

    // Firestore에서 데이터 가져오기
    for (var meeting in meetings) {
      if (meeting.startTime.isAfter(monthStart) &&
          meeting.startTime.isBefore(monthEnd)) {
        final duration = meeting.endTime.difference(meeting.startTime);

        if (CalendarConstants.timegroup_event.contains(meeting.subject)) {
          // 이벤트 타입 처리
          eventGroupDurations.putIfAbsent(meeting.subject, () => {});

          // Firestore에서 해당 이벤트의 type 필드 확인
          final snapshot = await _firestore
              .collection('timeslot_event')
              .where('startTime',
                  isEqualTo: Timestamp.fromDate(meeting.startTime))
              .where('endTime', isEqualTo: Timestamp.fromDate(meeting.endTime))
              .where('subject', isEqualTo: meeting.subject)
              .get();

          if (snapshot.docs.isNotEmpty) {
            final type = snapshot.docs.first.data()['type'] as String;
            eventGroupDurations[meeting.subject]![type] =
                (eventGroupDurations[meeting.subject]![type] ?? Duration.zero) +
                    duration;
          }
        } else {
          timeGroupDurations.putIfAbsent(meeting.subject, () => {});
          timeGroupDurations[meeting.subject]!['total'] =
              (timeGroupDurations[meeting.subject]!['total'] ?? Duration.zero) +
                  duration;
        }
      }
    }

    return Container(
      width: MediaQuery.of(context).size.width,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${now.year}년 ${now.month}월 타임슬롯',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          // 타임슬롯 그룹 행
          MouseRegion(
            cursor: SystemMouseCursors.grab,
            child: Scrollbar(
              controller: _scrollController,
              thumbVisibility: true,
              trackVisibility: true,
              child: SingleChildScrollView(
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                child: SizedBox(
                  height: 110,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ...CalendarConstants.timeGroups.map((timeGroup) {
                        final durations = timeGroupDurations[timeGroup] ?? {};
                        final totalDuration =
                            durations['total'] ?? Duration.zero;

                        final eventGroup = CalendarConstants.timegroup_event[
                            CalendarConstants.timeGroups.indexOf(timeGroup)];
                        final eventDurations =
                            eventGroupDurations[eventGroup] ?? {};
                        final addDuration =
                            eventDurations['add'] ?? Duration.zero;
                        final subDuration =
                            eventDurations['sub'] ?? Duration.zero;

                        return Container(
                          width: max(
                              MediaQuery.of(context).size.width * 0.3, 150.0),
                          margin: const EdgeInsets.only(right: 8.0),
                          child: _buildGroupSummaryCard(
                            timeGroup,
                            totalDuration,
                            addDuration,
                            subDuration,
                            CalendarConstants.timeGroupColors[timeGroup]!,
                            max(MediaQuery.of(context).size.width * 0.3, 150.0),
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 요약 카드 위젯 추출
  Widget _buildGroupSummaryCard(String title, Duration totalDuration,
      Duration addDuration, Duration subDuration, Color color, double width) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: SizedBox(
        width: width,
        child: SingleChildScrollView(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[200]!),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDuration(totalDuration),
                  style: const TextStyle(fontSize: 12),
                ),
                if (addDuration.inMinutes > 0)
                  Text(
                    '+ ${_formatDuration(addDuration)}',
                    style: const TextStyle(fontSize: 12, color: Colors.green),
                  ),
                if (subDuration.inMinutes > 0)
                  Text(
                    '- ${_formatDuration(subDuration)}',
                    style: const TextStyle(fontSize: 12, color: Colors.red),
                  ),
                const SizedBox(height: 2),
                Text(
                  '총 ${_formatDuration(totalDuration + addDuration - subDuration)}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    return '${hours > 0 ? '$hours시간 ' : ''}${minutes}분';
  }

  void _saveTimeSlot(DateTime selectedDate, TimeOfDay selectedEndTime,
      String selectedTimeGroup) {
    final DateTime endDateTime = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      selectedEndTime.hour,
      selectedEndTime.minute,
    );

    setState(() {
      final isEventType = selectedTimeGroup.startsWith('event');
      final color = isEventType
          ? CalendarConstants.timeGroupEventColors[selectedTimeGroup]!
          : CalendarConstants.timeGroupColors[selectedTimeGroup]!;

      final BaseMeeting newMeeting = isEventType
          ? EventMeeting(
              selectedTimeGroup,
              selectedDate,
              endDateTime,
              color,
              false,
              'add',
            )
          : GroupMeeting(
              selectedTimeGroup,
              selectedDate,
              endDateTime,
              color,
              false,
            );

      meetings.add(newMeeting);

      // 데이터소스 업데이트
      _meetingDataSource.appointments = meetings;
      _meetingDataSource.notifyListeners(
          CalendarDataSourceAction.reset, meetings);

      // Firestore에 추가
      addEventToFirestore(newMeeting);
    });
  }

  // 이벤트 삭제 시
  void _deleteTimeSlot(BaseMeeting meeting) {
    setState(() {
      meetings.remove(meeting);

      _meetingDataSource.appointments = meetings;
      _meetingDataSource.notifyListeners(
          CalendarDataSourceAction.reset, meetings);

      // Firestore에서 삭제
      deleteEventFromFirestore(meeting);
    });
  }

  // Firestore 관련 함수 수정
  Future<void> addEventToFirestore(BaseMeeting meeting) async {
    if (!mounted) return;

    try {
      if (CalendarConstants.timegroup_event.contains(meeting.subject)) {
        // 겹치는 간대 다시 확인
        bool isOverlapping = false;

        // 모든 미팅을 순회하면서 group 타입의 미팅과 시간이 겹치는지 확인
        for (var existingMeeting in meetings) {
          // group 타입의 미팅인 경우에만 체크
          if (CalendarConstants.timeGroups.contains(existingMeeting.subject)) {
            if (meeting.startTime.isBefore(existingMeeting.endTime) &&
                meeting.endTime.isAfter(existingMeeting.startTime)) {
              isOverlapping = true;
              break;
            }
          }
        }

        if (!mounted) return;
        await _firestore.collection('timeslot_event').add({
          'startTime': meeting.startTime,
          'endTime': meeting.endTime,
          'subject': meeting.subject,
          'type': isOverlapping ? 'sub' : 'add', // 겹치면 'sub', 안겹치면 'add'
        });
      } else {
        if (!mounted) return;
        await _firestore.collection('timeslot').add({
          'startTime': meeting.startTime,
          'endTime': meeting.endTime,
          'subject': meeting.subject,
        });
      }

      if (mounted) {
        _logger.i('Event added to Firestore');
      }
    } catch (e) {
      if (mounted) {
        _logger.e('Failed to add event: $e');
      }
    }
  }

  Future<void> deleteEventFromFirestore(BaseMeeting meeting) async {
    if (!mounted) return;

    try {
      final collections = ['timeslot_event', 'timeslot'];

      for (var collection in collections) {
        if (!mounted) return;
        final snapshot = await _firestore
            .collection(collection)
            .where('startTime', isEqualTo: meeting.startTime)
            .where('endTime', isEqualTo: meeting.endTime)
            .where('subject', isEqualTo: meeting.subject)
            .get();

        if (!mounted) return;
        for (var doc in snapshot.docs) {
          await doc.reference.delete();
        }
      }
      if (mounted) {
        _logger.i('Event deleted from Firestore');
      }
    } catch (e) {
      if (mounted) {
        _logger.e('Failed to delete event: $e');
      }
    }
  }

  // 이벤트 추가 다이얼로그
  void _showAddEventDialog(DateTime selectedDate) {
    // 모든 관련 변수 초기화
    existingGroup = '';
    selectedTimeGroup = CalendarConstants.timegroup_event[0];
    BaseMeeting? existingGroupMeeting;

    // 선택된 시간에 존재하는 group 찾기
    for (var meeting in meetings) {
      if (!CalendarConstants.timegroup_event.contains(meeting.subject) &&
          (meeting.startTime.isAtSameMomentAs(selectedDate) ||
              meeting.startTime.isBefore(selectedDate)) &&
          meeting.endTime.isAfter(selectedDate)) {
        existingGroupMeeting = meeting;
        existingGroup = meeting.subject;
        break;
      }
    }

    // 초기 이벤트 그룹 설정
    if (existingGroup.isNotEmpty) {
      // 그룹이 있는 경우 해당 그룹의 이벤트만 선택 가능
      int groupIndex = CalendarConstants.timeGroups.indexOf(existingGroup);
      if (groupIndex != -1) {
        selectedTimeGroup = CalendarConstants.timegroup_event[groupIndex];
      }
    }

    // 다음 그룹 시간 찾기
    DateTime? nextGroupStartTime;
    if (existingGroupMeeting != null) {
      for (var meeting in meetings) {
        if (!CalendarConstants.timegroup_event.contains(meeting.subject) &&
            meeting.startTime.isAfter(existingGroupMeeting.endTime)) {
          if (nextGroupStartTime == null ||
              meeting.startTime.isBefore(nextGroupStartTime)) {
            nextGroupStartTime = meeting.startTime;
          }
        }
      }
    }

    // 최대 가능한 duration 계산
    double maxDuration = 480.0; // 기본 최대값 (8시간)

    // 현재 그룹의 종료 시간까지 제한
    if (existingGroupMeeting != null) {
      maxDuration = min(
          maxDuration,
          existingGroupMeeting.endTime
              .difference(selectedDate)
              .inMinutes
              .toDouble());
    }

    // 다음 이벤트의 시작 시간까지 제한
    for (var meeting in meetings) {
      if (meeting.startTime.isAfter(selectedDate)) {
        double duration =
            meeting.startTime.difference(selectedDate).inMinutes.toDouble();
        if (duration < maxDuration) {
          maxDuration = duration;
        }
      }
    }

    // maxDuration이 최소값(30분) 미만인 경우 처리
    if (maxDuration < 30) {
      // 시간이 부족하다는 알림 표시
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('알림'),
          content: const Text('선택한 시간에 이벤트를 추가할 수 있는 충분한 시간이 없습니다.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('확인'),
            ),
          ],
        ),
      );
      return;
    }

    double initialStartValue =
        selectedDate.hour * 60 + selectedDate.minute.toDouble();
    double totalDuration = min(30, maxDuration);

    selectedEndTime = TimeOfDay(
      hour: ((initialStartValue + totalDuration) ~/ 60),
      minute: ((initialStartValue + totalDuration) % 60).toInt(),
    );

    final endTimeController = TextEditingController(
      text: _formatTime(selectedEndTime),
    );

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('일정 추가'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 300,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 16),
                  if (existingGroup.isNotEmpty)
                    Text(
                      '그룹: $existingGroup',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: selectedTimeGroup,
                    decoration: const InputDecoration(
                      labelText: '이벤트 타입',
                    ),
                    items: (existingGroup.isEmpty
                            ? CalendarConstants
                                .timegroup_event // 그룹이 없으면 모든 이벤트 표시
                            : [
                                CalendarConstants.timegroup_event[
                                    CalendarConstants.timeGroups
                                        .indexOf(existingGroup)]
                              ] // 그룹이 있으면 해당 그룹의 이벤트만 표시
                        )
                        .map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setDialogState(() {
                        selectedTimeGroup = newValue!;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  StatefulBuilder(
                    builder: (context, setState) => Column(
                      children: [
                        if (maxDuration > 30) // 최소값보다 큰 경우에만 슬라이더 표시
                          SfSlider(
                            min: 30,
                            max: maxDuration,
                            value: totalDuration,
                            interval: min(120, maxDuration / 4),
                            stepSize: 30,
                            showTicks: true,
                            showLabels: true,
                            enableTooltip: true,
                            labelFormatterCallback:
                                (dynamic value, String formattedText) {
                              double hours = value / 60;
                              return '${hours.toStringAsFixed(1)}시간';
                            },
                            tooltipTextFormatterCallback:
                                (dynamic value, String formattedText) {
                              int minutes = value.toInt();
                              if (minutes < 60) return '$minutes분';
                              int hours = minutes ~/ 60;
                              int remainingMinutes = minutes % 60;
                              return remainingMinutes > 0
                                  ? '$hours시간 $remainingMinutes분'
                                  : '$hours시간';
                            },
                            activeColor: Theme.of(context).primaryColor,
                            onChanged: (dynamic value) {
                              setState(() {
                                totalDuration = value;
                                TimeOfDay endTime = TimeOfDay(
                                  hour: ((initialStartValue + totalDuration) ~/
                                      60),
                                  minute:
                                      ((initialStartValue + totalDuration) % 60)
                                          .toInt(),
                                );
                                endTimeController.text = _formatTime(endTime);
                                selectedEndTime = endTime;
                              });
                            },
                          ),
                        const SizedBox(height: 16),
                        Text(
                          '${DateFormat('HH:mm').format(selectedDate)} ~ ${DateFormat('HH:mm').format(selectedDate.add(Duration(minutes: totalDuration.toInt())))}',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () {
                _saveTimeSlot(selectedDate, selectedEndTime, selectedTimeGroup);
                Navigator.pop(context);
              },
              child: const Text('저장'),
            ),
          ],
        ),
      ),
    );
  }

  // 삭제 확인 다이얼로그
  void _showDeleteEventDialog(BaseMeeting meeting) {
    // 디버그 로그 추가
    _logger.d('Selected Meeting Info:');
    _logger.d('Subject: ${meeting.subject}');
    _logger.d(
        'Is in timegroup_event: ${CalendarConstants.timegroup_event.contains(meeting.subject)}');
    _logger.d(
        'Is in timeGroups: ${CalendarConstants.timeGroups.contains(meeting.subject)}');
    _logger.d('Meeting Type: ${meeting.runtimeType}');
    _logger.d('All timeGroups: ${CalendarConstants.timeGroups}');
    _logger.d('All timegroup_events: ${CalendarConstants.timegroup_event}');

    // event 타입이 아닌 경우 삭제 불가능 알림 표시
    if (!CalendarConstants.timegroup_event.contains(meeting.subject) &&
        CalendarConstants.timeGroups.contains(meeting.subject)) {
      _logger.d('삭제 불가 조건 충족: Group 타임슬롯');
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('삭제 불가'),
          content: const Text('그룹 타임슬롯은 삭제할 수 없습니다.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('확인'),
            ),
          ],
        ),
      );
      return;
    }

    _logger.d('삭제 가능: Event 타임슬롯');
    // event 타입인 경우에만 삭제 다이얼로그 표시
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('일정 삭제'),
        content: Text('이 일정을 삭제하시겠습니까?\n${_formatTimeRange(
          meeting.startTime.hour * 60 + meeting.startTime.minute.toDouble(),
          meeting.endTime.hour * 60 + meeting.endTime.minute.toDouble(),
        )}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              _deleteTimeSlot(meeting);
              Navigator.pop(context);
            },
            child: const Text('삭제'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  // 시간 포맷팅을 위한 헬퍼 메서드
  String _formatTimeRange(double start, double end) {
    final startTime = TimeOfDay(
      hour: start ~/ 60,
      minute: (start % 60).toInt(),
    );
    final endTime = TimeOfDay(
      hour: end ~/ 60,
      minute: (end % 60).toInt(),
    );

    return '${_formatTime(startTime)} - ${_formatTime(endTime)}';
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
