import 'package:flutter/gestures.dart'; // 추가
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// 필요한 패키지들을 가져옵니다
import 'package:syncfusion_flutter_calendar/calendar.dart';
import 'package:logger/logger.dart';
import 'package:syncfusion_flutter_sliders/sliders.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' show max;

// Firestore 인스턴스 가져오기
final FirebaseFirestore _firestore = FirebaseFirestore.instance;

// 상수 정의
class CalendarConstants {
  static const startHour = 0;
  static const endHour = 24;
  static const timeSlotDuration = Duration(minutes: 30);
  static const defaultMeetingDuration = Duration(minutes: 30);
  static const defaultStartHour = 9;
  static const maxDurationHours = 24; // 최대 24시간으로 설정

  static const timeGroups = [
    'group-1',
    'group-2',
    'group-3',
    'group-4',
  ];

  // 트렌디한 색상 팔트 추
  static final timeGroupColors = {
    'group-1': const Color(0xFF6366F1), // Indigo
    'group-2': const Color(0xFFEC4899), // Pink
    'group-3': const Color(0xFF14B8A6), // Teal
    'group-4': const Color(0xFFF59E0B), // Amber
  };
}

// 날짜/시간 유틸리티
class DateTimeUtils {
  static DateTime roundToNearestThirtyMinutes(DateTime dateTime) {
    final int minutes = dateTime.minute;
    final int roundedMinutes = (minutes / 30).round() * 30;
    return DateTime(
      dateTime.year,
      dateTime.month,
      dateTime.day,
      dateTime.hour,
      roundedMinutes,
    );
  }

  static bool isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }
}

class Meeting {
  String subject;
  DateTime startTime;
  DateTime endTime;
  Color background;
  bool isAllDay;
  final _logger = Logger();

  Meeting(this.subject, DateTime fromTime, DateTime toTime, this.background,
      this.isAllDay)
      : startTime = DateTimeUtils.roundToNearestThirtyMinutes(fromTime),
        endTime = DateTimeUtils.roundToNearestThirtyMinutes(toTime) {
    _validateAndAdjustTimes();
  }

  void _validateAndAdjustTimes() {
    if (startTime.isAfter(endTime)) {
      endTime = startTime.add(CalendarConstants.defaultMeetingDuration);
    }
  }

  void updateEndTime(DateTime newEndTime) {
    _logger.i('updateEndTime 호출 ======================');
    _logger.i('현재 시작 시간: $startTime');
    _logger.i('현재 종료 시간: $endTime');
    _logger.i('요청된 새 종료 시간: $newEndTime');

    if (!newEndTime.isBefore(startTime)) {
      endTime = DateTimeUtils.roundToNearestThirtyMinutes(newEndTime);
      _logger.i('종료 시간 업데이트 성공: $endTime');
    } else {
      endTime = startTime.add(CalendarConstants.defaultMeetingDuration);
      _logger.i('유효하지 않은 종료 시간, 기본 지속 시간으로 설정: $endTime');
    }
  }

  bool overlapsWith(DateTime start, DateTime end) {
    return (startTime.isBefore(end) && endTime.isAfter(start));
  }
}

// TimeslotData 클래스 정의
class TimeslotData {
  final DateTime startTime;
  final DateTime endTime;
  final String subject;

  TimeslotData({
    required this.startTime,
    required this.endTime,
    required this.subject,
  });
}

// TimeslotCountDataStruct 클래스 추가
class TimeslotCountDataStruct {
  final double totalTime;
  final double eventAddTime;
  final double eventSubTime;
  final double timeslotTime;

  TimeslotCountDataStruct({
    this.totalTime = 0.0,
    this.eventAddTime = 0.0,
    this.eventSubTime = 0.0,
    this.timeslotTime = 0.0,
  });
}

class AddTimeslotCalendar extends StatefulWidget {
  const AddTimeslotCalendar({
    super.key,
    this.width,
    this.height,
  });

  final double? width;
  final double? height;

  @override
  State<AddTimeslotCalendar> createState() => _AddTimeslotCalendarState();
}

class _AddTimeslotCalendarState extends State<AddTimeslotCalendar> {
  List<Meeting> meetings = [];
  List<TimeslotData> timeSlotList = []; // FFAppState().timeSlotList 대체
  late final MeetingDataSource _meetingDataSource;
  String selectedTimeGroup = CalendarConstants.timeGroups[0];
  TimeOfDay selectedEndTime = TimeOfDay.now();
  final _logger = Logger();

  // 타임슬롯 요약 데이터를 저장할 상태 변수 추가
  Map<String, Duration> timeGroupDurations = {};

  // 추가: timeSlotCount 상태 변수
  List<TimeslotCountDataStruct> timeSlotCount = [];

  @override
  void initState() {
    super.initState();
    _meetingDataSource = MeetingDataSource(meetings);
    _loadEventsFromFirestore(); // Firestore에서 데이터 로드
  }

  // Firestore에서 이벤트 로드하는 함수 추가
  Future<void> _loadEventsFromFirestore() async {
    try {
      final snapshot = await _firestore.collection('timeslot').get();
      final List<Meeting> loadedMeetings = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final startTime = (data['startTime'] as Timestamp).toDate();
        final endTime = (data['endTime'] as Timestamp).toDate();
        final subject = data['subject'] as String;

        loadedMeetings.add(Meeting(
          subject,
          startTime,
          endTime,
          CalendarConstants.timeGroupColors[subject] ?? Colors.grey,
          false,
        ));
      }

      setState(() {
        meetings = loadedMeetings;
        _meetingDataSource.appointments = meetings;
        _meetingDataSource.notifyListeners(
            CalendarDataSourceAction.reset, meetings);

        // AppState 업데이트
        updateTimeSlotList();

        // 타임슬롯 요약 업데이트 추가
        _updateTimeSlotSummary();
      });
    } catch (e) {
      _logger.e('Failed to load events from Firestore: $e');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 기존의 _getDataSource() 호출 제거
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Column(
      children: [
        // 타임슬롯 요약을 상단에 고정
        Container(
          padding: const EdgeInsets.all(16),
          constraints: const BoxConstraints(maxHeight: 200), // 높이 줄임
          child: _buildTimeSlotSummary(),
        ),
        // 캘린더 부분을 스크롤 가능하게
        Expanded(
          child: SingleChildScrollView(
            child: SizedBox(
              height: screenHeight * 0.6,
              child: SfCalendar(
                view: CalendarView.week,
                firstDayOfWeek: 7,
                timeSlotViewSettings: TimeSlotViewSettings(
                  startHour: CalendarConstants.startHour.toDouble(),
                  endHour: CalendarConstants.endHour.toDouble(),
                  timeInterval: CalendarConstants.timeSlotDuration,
                  timeFormat: 'HH:mm',
                  timeIntervalHeight: 30,
                  timeRulerSize: 70,
                  timeTextStyle: const TextStyle(
                    fontSize: 12,
                    height: 1.0,
                  ),
                  timelineAppointmentHeight: 30,
                ),
                onTap: _handleCalendarTap,
                dataSource: _meetingDataSource,
                selectionDecoration: _buildSelectionDecoration(),
                onLongPress: _handleEventTap,
                allowAppointmentResize: false,
                appointmentBuilder: (context, calendarAppointmentDetails) {
                  final appointment =
                      calendarAppointmentDetails.appointments.first;
                  final meeting = meetings.firstWhere(
                    (m) =>
                        m.startTime == appointment.startTime &&
                        m.endTime == appointment.endTime,
                    orElse: () => Meeting(
                      'default',
                      appointment.startTime,
                      appointment.endTime,
                      Colors.grey,
                      false,
                    ),
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
          ),
        ),
      ],
    );
  }

  BoxDecoration _buildSelectionDecoration() {
    return BoxDecoration(
      border: Border.all(color: Theme.of(context).primaryColor, width: 2),
      borderRadius: BorderRadius.circular(4),
    );
  }

  void _handleCalendarTap(CalendarTapDetails details) {
    if (details.targetElement == CalendarElement.calendarCell) {
      DateTime selectedDate = details.date!;
      final DateTime roundedDate =
          DateTimeUtils.roundToNearestThirtyMinutes(selectedDate);
      _showAddTaskDialog(roundedDate);
    }
  }

  // 일정 추가 다이얼로그를 보여주는 함수
  void _showAddTaskDialog(DateTime selectedDate) {
    double initialStartValue =
        selectedDate.hour * 60 + selectedDate.minute.toDouble();
    double totalDuration = 30;

    // 최대 지속 시간을 12시간(720분)으로 설정
    double maxDuration = 480.0;

    // 다음 그룹의 시작 시간이 있는 경우, 해당 시간까지로 제한
    for (var meeting in meetings) {
      if (!CalendarConstants.timeGroups.contains(meeting.subject) &&
          meeting.startTime.isAfter(selectedDate)) {
        double duration =
            meeting.startTime.difference(selectedDate).inMinutes.toDouble();
        if (duration < maxDuration) {
          maxDuration = duration;
        }
      }
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('일정 추가'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 16),
                DropdownButton<String>(
                  value: selectedTimeGroup,
                  isExpanded: true,
                  items: CalendarConstants.timeGroups
                      .map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setDialogState(() {
                      selectedTimeGroup = newValue!;
                    });
                    setState(() {
                      selectedTimeGroup = newValue!;
                    });
                  },
                ),
                const SizedBox(height: 16),
                SfSlider(
                  min: 30,
                  max: maxDuration,
                  value: totalDuration,
                  interval: maxDuration > 120 ? 120 : maxDuration / 4,
                  stepSize: 30,
                  showTicks: true,
                  showLabels: true,
                  enableTooltip: true,
                  labelPlacement: LabelPlacement.onTicks,
                  labelFormatterCallback:
                      (dynamic value, String formattedText) {
                    double hours = value / 60;
                    if (hours >= 24) return '24시간';
                    return '${hours.toStringAsFixed(1)}시간';
                  },
                  tooltipTextFormatterCallback:
                      (dynamic value, String formattedText) {
                    int minutes = value.toInt();
                    int hours = minutes ~/ 60;
                    int remainingMinutes = minutes % 60;
                    if (hours == 0) return '$remainingMinutes분';
                    return remainingMinutes > 0
                        ? '$hours시간 $remainingMinutes분'
                        : '$hours시간';
                  },
                  activeColor: Theme.of(context).primaryColor,
                  onChanged: (dynamic value) {
                    setDialogState(() {
                      // setState 대신 setDialogState 사용
                      totalDuration = value;
                      selectedEndTime = TimeOfDay(
                        hour: ((initialStartValue + totalDuration) ~/ 60) % 24,
                        minute:
                            ((initialStartValue + totalDuration) % 60).toInt(),
                      );
                    });
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  '${DateFormat('MM/dd HH:mm').format(selectedDate)} ~ '
                  '${DateFormat('MM/dd HH:mm').format(selectedDate.add(Duration(minutes: totalDuration.toInt())))}',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 16),
                // 주간 반복 체크박스 추가
                const ListTile(
                  title: Text('매주 반복'),
                  trailing: Icon(Icons.check, color: Colors.green),
                ),
              ],
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

  // 시  포맷팅을 위한 헬 메서드
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

  // 샘플 데이터를 생성하는 함수
  List<Meeting> _getDataSource() {
    final List<Meeting> meetings = <Meeting>[];
    final DateTime today = DateTime.now();
    final String defaultTimeGroup = CalendarConstants.timeGroups[0];

    // 샘플 일정도 _saveTimeSlot 사용
    _saveTimeSlot(
      DateTime(today.year, today.month, today.day, 10, 0),
      TimeOfDay(hour: 11, minute: 30),
      defaultTimeGroup,
    );

    return meetings;
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
      // 기존 이벤트 삭제 전에 새 이벤트들을 먼저 생성
      final lastDayOfYear = DateTime(selectedDate.year, 12, 31, 23, 59, 59);
      DateTime currentDate = selectedDate;
      List<Meeting> newMeetings = [];

      // 새 이벤트 생성
      while (!currentDate.isAfter(lastDayOfYear)) {
        final newMeeting = Meeting(
          selectedTimeGroup,
          DateTime(
            currentDate.year,
            currentDate.month,
            currentDate.day,
            selectedDate.hour,
            selectedDate.minute,
          ),
          DateTime(
            currentDate.year,
            currentDate.month,
            currentDate.day,
            endDateTime.hour,
            endDateTime.minute,
          ),
          CalendarConstants.timeGroupColors[selectedTimeGroup]!,
          false,
        );

        newMeetings.add(newMeeting);
        currentDate = currentDate.add(const Duration(days: 7));
      }

      // Firestore에서 겹치는 이벤트 삭제
      deleteOverlappingEventsFromFirestore(
        selectedDate.weekday,
        selectedDate.hour,
        selectedDate.minute,
      ).then((_) {
        // 로컬 meetings 리스트에서 겹치는 이트 삭제
        meetings.removeWhere((m) =>
            m.startTime.weekday == selectedDate.weekday &&
            m.startTime.hour == selectedDate.hour &&
            m.startTime.minute == selectedDate.minute);

        // 새 이벤트들을 로컬 리스트에 추가
        meetings.addAll(newMeetings);

        // 데이터소스 데이트
        _meetingDataSource.appointments = meetings;
        _meetingDataSource.notifyListeners(
            CalendarDataSourceAction.reset, meetings);

        // FFAppState 대신 로컬 변수 업데이트
        updateTimeSlotList();

        // 새로운 이벤트들을 Firestore에 추가
        for (var newMeeting in newMeetings) {
          addEventToFirestore(newMeeting);
        }

        // 타임슬롯 요약 업데이트
        _updateTimeSlotSummary();
      });
    });
  }

  // Firestore에서 겹치는 일정 삭제를 위한 새로운 함수
  Future<void> deleteOverlappingEventsFromFirestore(
      int weekday, int hour, int minute) async {
    try {
      final snapshot = await _firestore.collection('timeslot').get();
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final startTime = (data['startTime'] as Timestamp).toDate();

        if (startTime.weekday == weekday &&
            startTime.hour == hour &&
            startTime.minute == minute) {
          await doc.reference.delete();
        }
      }
    } catch (e) {
      print('Failed to delete overlapping events: $e');
    }
  }

  // 이벤트 탭 핸들러 수정
  void _handleEventTap(CalendarLongPressDetails details) {
    if (details.targetElement == CalendarElement.appointment &&
        details.appointments != null &&
        details.appointments!.isNotEmpty) {
      final appointment = details.appointments!.first;

      // meetings 리스트에서 해당하는 미팅 찾기
      final matchingMeetings = meetings.where((meeting) =>
          meeting.startTime.hour == appointment.startTime.hour &&
          meeting.startTime.minute == appointment.startTime.minute &&
          meeting.endTime.hour == appointment.endTime.hour &&
          meeting.endTime.minute == appointment.endTime.minute);

      // 매칭되는 미팅이 있을 경우에만 삭제 다이얼로그 표시
      if (matchingMeetings.isNotEmpty) {
        _showDeleteConfirmationDialog(matchingMeetings.first);
      }
    }
  }

  // 삭제 확인 다이얼로그
  void _showDeleteConfirmationDialog(Meeting meeting) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('일정 제'),
        content: Text('이 일정을 삭제하시겠니까?\n${_formatTimeRange(
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

  // 일정 삭제 시
  void _deleteTimeSlot(Meeting meeting) {
    setState(() {
      // 해당 년도의 마지막 날을 12월 31일로 수정하고 시간까지 포함
      final lastDayOfYear =
          DateTime(meeting.startTime.year, 12, 31, 23, 59, 59);
      DateTime currentDate = meeting.startTime;
      List<Meeting> eventsToDelete = [];

      // 수정된 부분: currentDate가 lastDayOfYear보다 작거나 같을 때까지 반복
      while (!currentDate.isAfter(lastDayOfYear)) {
        eventsToDelete.addAll(meetings.where((m) =>
            m.startTime.year == currentDate.year &&
            m.startTime.weekday == currentDate.weekday &&
            m.startTime.hour == meeting.startTime.hour &&
            m.startTime.minute == meeting.startTime.minute &&
            m.subject == meeting.subject));
        currentDate = currentDate.add(const Duration(days: 7));
      }

      // 찾은 이벤트들을 meetings 리스트에서 제거
      meetings.removeWhere((m) => eventsToDelete.contains(m));

      _meetingDataSource.appointments = meetings;
      _meetingDataSource.notifyListeners(
          CalendarDataSourceAction.reset, meetings);

      // FFAppState 대신 로컬 변수 업데이트
      updateTimeSlotList();

      // 찾은 이벤트들만 Firestore에서 삭제
      for (var eventToDelete in eventsToDelete) {
        deleteEventFromFirestore(eventToDelete);
      }

      // 타임슬롯 요약 업데이트
      _updateTimeSlotSummary();
    });
  }

  // 타임슬롯 요약을 업데이트하는 새로운 메서드
  void _updateTimeSlotSummary() {
    final now = DateTime.now();
    Map<String, Duration> newTimeGroupDurations = {};
    List<TimeslotCountDataStruct> newTimeSlotCount = List.filled(
        CalendarConstants.timeGroups.length, TimeslotCountDataStruct());

    // 각 그룹별 시간 계산
    for (var meeting in meetings) {
      if (meeting.startTime.year == now.year &&
          meeting.startTime.month == now.month) {
        final duration = meeting.endTime.difference(meeting.startTime);
        newTimeGroupDurations[meeting.subject] =
            (newTimeGroupDurations[meeting.subject] ?? Duration.zero) + duration;
      }
    }

    // TimeslotCountDataStruct 생성 및 리스트에 추가
    for (var i = 0; i < CalendarConstants.timeGroups.length; i++) {
      final timeGroup = CalendarConstants.timeGroups[i];
      final duration = newTimeGroupDurations[timeGroup] ?? Duration.zero;
      final timeslotHours = duration.inMinutes / 60.0;

      final existingData = timeSlotCount.length > i ? timeSlotCount[i] : null;

      final eventAddTime = existingData?.eventAddTime ?? 0.0;
      final eventSubTime = existingData?.eventSubTime ?? 0.0;

      final totalTime = max(0, timeslotHours + eventAddTime - eventSubTime);

      newTimeSlotCount[i] = TimeslotCountDataStruct(
        totalTime: double.parse(totalTime.toStringAsFixed(1)),
        eventAddTime: eventAddTime,
        eventSubTime: eventSubTime,
        timeslotTime: double.parse(timeslotHours.toStringAsFixed(1)),
      );
    }

    // 상태 업데이트
    setState(() {
      timeGroupDurations = newTimeGroupDurations;
      timeSlotCount = newTimeSlotCount;
    });

    _logger.i(
        'TimeSlotCount 업데이트됨: ${timeSlotCount.asMap().entries.map((e) => 'group-${e.key + 1}: total=${e.value.totalTime}시간, timeslot=${e.value.timeslotTime}시간, '
            'add=${e.value.eventAddTime}시간, sub=${e.value.eventSubTime}시간').join('\n')}');
  }

  // 타임슬롯 요약을 보여주는 새로운 위젯
  Widget _buildTimeSlotSummary() {
    final now = DateTime.now();
    final itemWidth = 120.0;
    final scrollController = ScrollController();

    return Container(
      width: double.infinity,
      height: 120,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
          Expanded(
            child: Scrollbar(
              controller: scrollController,
              thumbVisibility: true,
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(
                  dragDevices: {
                    PointerDeviceKind.touch,
                    PointerDeviceKind.mouse,
                  },
                  scrollbars: true,
                ),
                child: SingleChildScrollView(
                  controller: scrollController,
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: CalendarConstants.timeGroups.map((timeGroup) {
                      final duration =
                          timeGroupDurations[timeGroup] ?? Duration.zero;
                      final hours = duration.inHours;
                      final minutes = (duration.inMinutes % 60);

                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: SizedBox(
                          width: itemWidth,
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
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: CalendarConstants
                                            .timeGroupColors[timeGroup],
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        timeGroup.replaceFirst(
                                            'timegroup', 'group'),
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
                                  '${hours > 0 ? '$hours시간 ' : ''}${minutes}분',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // FFAppState().timeSlotList 업데이트 부분을 다음과 같이 변경
  void updateTimeSlotList() {
    timeSlotList = meetings
        .map((meeting) => TimeslotData(
              startTime: meeting.startTime,
              endTime: meeting.endTime,
              subject: meeting.subject,
            ))
        .toList();
  }
}

// 캘린더에 시될 일정 데이터를 관리하는 클래스
class MeetingDataSource extends CalendarDataSource {
  MeetingDataSource(List<Meeting> source) {
    appointments = source;
  }

  @override
  DateTime getStartTime(int index) {
    final Meeting meeting = appointments![index];
    return meeting.startTime;
  }

  @override
  DateTime getEndTime(int index) {
    final Meeting meeting = appointments![index];
    return meeting.endTime;
  }

  @override
  String getSubject(int index) {
    final Meeting meeting = appointments![index];
    return meeting.subject;
  }

  @override
  Color getColor(int index) {
    final Meeting meeting = appointments![index];
    return CalendarConstants.timeGroupColors[meeting.subject] ?? Colors.grey;
  }

  @override
  bool isAllDay(int index) {
    final Meeting meeting = appointments![index];
    return meeting.isAllDay;
  }

  @override
  String? getRecurrenceRule(int index) {
    return null; // recurrenceRule 항상 null 반환
  }
}

// 이벤트 추가 함수
Future<void> addEventToFirestore(Meeting meeting) async {
  try {
    await _firestore.collection('timeslot').add({
      'startTime': meeting.startTime,
      'endTime': meeting.endTime,
      'subject': meeting.subject,
    });

    print(
        'Timeslot Added - Start: ${DateFormat('yyyy-MM-dd HH:mm').format(meeting.startTime)}, '
        'End: ${DateFormat('yyyy-MM-dd HH:mm').format(meeting.endTime)}, '
        'Group: ${meeting.subject}');
  } catch (e) {
    print('Failed to add timeslot: $e');
  }
}

// 이벤트 삭제 함수
Future<void> deleteEventFromFirestore(Meeting meeting) async {
  print(
      'Timeslot Deleted - Start: ${DateFormat('yyyy-MM-dd HH:mm').format(meeting.startTime)}, '
      'End: ${DateFormat('yyyy-MM-dd HH:mm').format(meeting.endTime)}');

  try {
    final snapshot = await _firestore
        .collection('timeslot')
        .where('startTime', isEqualTo: meeting.startTime)
        .where('endTime', isEqualTo: meeting.endTime)
        .where('subject', isEqualTo: meeting.subject)
        .get();

    for (var doc in snapshot.docs) {
      await doc.reference.delete();
    }
  } catch (e) {
    print('Failed to delete timeslot: $e');
  }
}

// TimeOfDay 확장
extension TimeOfDayExtension on TimeOfDay {
  DateTime toDateTime() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, hour, minute);
  }
}
