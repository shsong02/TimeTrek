import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '/backend/app_state.dart';

import 'package:syncfusion_flutter_calendar/calendar.dart';
import 'dart:async'; // 추가
import 'package:rxdart/rxdart.dart'; // rxdart 패키지 import 확인
import 'package:google_fonts/google_fonts.dart';
import 'package:markdown_widget/markdown_widget.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart' show PlatformFile;
import 'package:flutter_markdown/flutter_markdown.dart';
import 'dart:typed_data'; // 추가
import 'package:image/image.dart' as img; // 추가

import '/backend/backend.dart';
import '/components/new_calendar_event.dart';
import '/theme/time_trek_theme.dart'; // time_trek_theme 패키지 추가

class ActionCalendar extends StatefulWidget {
  const ActionCalendar({
    super.key,
    this.width,
    this.height,
  });

  final double? width;
  final double? height;

  @override
  State<ActionCalendar> createState() => _ActionCalendarState();
}

class _ActionCalendarState extends State<ActionCalendar> {
  late CalendarController _controller;
  StreamController<void>? _refreshController;
  late Future<void> _initialDataFuture;
  int _rotationAngle = 0;
  late TextEditingController _descriptionController;
  String markdownText = '';

  @override
  void initState() {
    super.initState();
    _controller = CalendarController();
    _controller.view = CalendarView.schedule;
    _initialDataFuture = _loadInitialData();
    _descriptionController = TextEditingController(text: markdownText);

    // 지연된 초기화를 위해 WidgetsBinding 사용
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshController = StreamController<void>.broadcast();
      _controller.addPropertyChangedListener(_handleViewChanged);
      _checkAndUpdateEventStatus();
    });
  }

  Future<void> _loadInitialData() async {
    await _checkAndUpdateEventStatus();
  }

  Future<void> _checkAndUpdateEventStatus() async {
    print('=== _checkAndUpdateEventStatus 시작 ===');
    final now = DateTime.now();
    final events = await queryCalendarEventRecord().first;
    print('calendar_event 콜렉션 조회: ${events.length}개의 이벤트 로드됨');

    for (var event in events) {
      if (event.endTime != null &&
          event.endTime!.isBefore(now) &&
          event.actionStatus == 'scheduled' &&
          event.actionStatus != 'completed') {
        // Firestore 업데이트
        await event.reference.update({
          'action_status': 'pending',
        });

        // ActionList 컬렉션 업데이트
        final actionListQuery = FirebaseFirestore.instance
            .collection('action_list')
            .where('action_name', isEqualTo: event.actionName);

        final actionListDocs = await actionListQuery.get();
        print('action_list 콜렉션 조회 (action_name=${event.actionName}): ${actionListDocs.docs.length}개의 문서 로드됨');

        if (actionListDocs.docs.isNotEmpty) {
          await actionListDocs.docs.first.reference.update({
            'action_status': 'pending',
          });
        }

        // 로그 출력
        print('이벤트 상태 업데이트: ${event.actionName} - scheduled에서 pending으로 변경됨');
      }
    }
    print('=== _checkAndUpdateEventStatus 종료 ===\n');
  }

  @override
  void dispose() {
    _controller.removePropertyChangedListener(_handleViewChanged);
    _controller.dispose();
    _refreshController?.close();
    _descriptionController.dispose();
    super.dispose();
  }

  void _handleViewChanged(String propertyName) {
    if (propertyName == 'calendarView') {
      _refreshController?.add(null);
    }
  }

  void _showReminderSettings(CalendarEventRecord event) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return ChangedActionEventWidget(
          event: event,
          refreshController:
              _refreshController ?? StreamController<void>.broadcast(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: TimeTrekTheme.lightTheme, // time_trek_theme 적용
      child: StreamBuilder<List<CalendarEventRecord>>(
        stream: _refreshController == null
            ? queryCalendarEventRecord()
            : Rx.merge([
                queryCalendarEventRecord(),
                _refreshController!.stream
                    .flatMap((_) => queryCalendarEventRecord())
              ]),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          return Column(
            children: [
              // 뷰 전환 버튼 추가
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    // controller를 사용하여 뷰 변경
                    onPressed: () => _controller.view = CalendarView.month,
                    child: Text('월간'),
                  ),
                  TextButton(
                    // controller를 사용하여 뷰 변경
                    onPressed: () => _controller.view = CalendarView.week,
                    child: Text('주간'),
                  ),
                  TextButton(
                    onPressed: () => _controller.view = CalendarView.schedule,
                    child: Text('일정'),
                  ),
                ],
              ),
              Expanded(
                child: SfCalendar(
                  controller: _controller, // controller 추가
                  dataSource: EventDataSource(snapshot.data!),
                  monthViewSettings: const MonthViewSettings(
                    showAgenda: true,
                  ),
                  scheduleViewSettings: const ScheduleViewSettings(
                    hideEmptyScheduleWeek: true,
                    monthHeaderSettings: MonthHeaderSettings(
                      height: 70,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  onTap: (CalendarTapDetails details) {
                    if (details.appointments != null &&
                        details.appointments!.isNotEmpty) {
                      _showReminderSettings(
                          details.appointments!.first as CalendarEventRecord);
                    }
                  },
                  appointmentTextStyle: const TextStyle(
                    fontFamily: 'NotoSansKR',
                    fontSize: 12,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class EventDataSource extends CalendarDataSource {
  static const timeGroups = [
    'group-1',
    'group-2',
    'group-3',
    'group-4',
  ];

  static final timeGroupColors = {
    'group-1': const Color(0xFF6366F1),
    'group-2': const Color(0xFFEC4899),
    'group-3': const Color(0xFF14B8A6),
    'group-4': const Color(0xFFF59E0B),
  };

  // 상태별 아이콘 스타일 정의
  static final Map<String, Map<String, dynamic>> statusStyles = {
    'scheduled': {
      'icon': '📅',
      'color': const Color(0xFF4CAF50),
    },
    'pending': {
      'icon': '⏳',
      'color': const Color(0xFFFFA726),
    },
    'completed': {
      'icon': '✅',
      'color': const Color(0xFF2196F3),
    },
    'delayed': {
      'icon': '⏰',
      'color': const Color(0xFFFF5722),
    },
    'dropped': {
      'icon': '❌',
      'color': const Color(0xFF9E9E9E),
    },
    'transferred': {
      'icon': '↗️',
      'color': const Color(0xFF9C27B0),
    },
  };

  EventDataSource(List<CalendarEventRecord> events) {
    appointments = events.where((event) => 
      event.startTime != null && 
      event.endTime != null &&
      event.actionName != null
    ).toList();
  }

  @override
  DateTime getStartTime(int index) {
    return appointments![index].startTime!;
  }

  @override
  DateTime getEndTime(int index) {
    return appointments![index].endTime!;
  }

  @override
  String getSubject(int index) {
    final event = appointments![index] as CalendarEventRecord;
    if (event.actionName == null) return '';
    
    final statusStyle = statusStyles[event.actionStatus] ??
        {'icon': '❓', 'color': const Color(0xFF757575)};

    final splitInfo = (event.actionSplitCount ?? 0) > 1
        ? ' (${event.actionSplitNum}/${event.actionSplitCount})'
        : '';

    return '${statusStyle['icon']} ${event.actionName}$splitInfo${event.reminderEnabled == true ? ' 🔔' : ''}';
  }

  @override
  Color getColor(int index) {
    final CalendarEventRecord event =
        appointments![index] as CalendarEventRecord;
    // completed 상태일 경우 회색으로 변경
    if (event.actionStatus == 'completed') {
      return Colors.grey;
    }
    // pending 상태일 경우 보라색으로 변경
    if (event.actionStatus == 'pending') {
      return const Color(0xFF9C27B0); // 보라색
    }
    return timeGroupColors[event.timegroup] ?? const Color(0xFF6366F1);
  }
}

// 알림 설정을 위한 Bottom Sheet 위젯
class ChangedActionEventWidget extends StatefulWidget {
  final CalendarEventRecord event;
  final StreamController<void> refreshController;

  const ChangedActionEventWidget({
    Key? key,
    required this.event,
    required this.refreshController,
  }) : super(key: key);

  @override
  State<ChangedActionEventWidget> createState() =>
      _ChangedActionEventWidgetState();
}
class _ChangedActionEventWidgetState extends State<ChangedActionEventWidget> {
  late Future<Map<String, dynamic>> _initialDataFuture;
  late TextEditingController _descriptionController;
  Map<String, dynamic>? _cachedData;
  List<DateTime>? _cachedTimeSlots;

  // 이미지 업로드 목적 선택을 위한 변수
  String? selectedImagePurpose = 'purpose1'; // 기본값을 'purpose1'으로 설정

  // 이미지 업로드 관련 변수
  List<XFile> selectedImages = [];
  List<String> imageUrls = [];

  bool _isAnalyzing = false; // _isAnalyzing 변수 추가

  String? _encodedImage; // base64 인코딩된 이미지를 저장할 변수 추가

  @override
  void initState() {
    super.initState();
    _initialDataFuture = _loadInitialData();
    _descriptionController = TextEditingController(text: markdownText);
    selectedStatus = widget.event.actionStatus;
    selectedReminderMinutes = widget.event.reminderMinutes ?? 30;
    markdownText = widget.event.actionStatusDescription ?? '';
  }

  Future<Map<String, dynamic>> _loadInitialData() async {
    try {
      // action_list 데이터 로드
      final actionListQuery = await FirebaseFirestore.instance
          .collection('action_list')
          .where('goal_name', isEqualTo: widget.event.goalName)
          .get();

      // goal_list 데이터 로드
      final goalQuery = await FirebaseFirestore.instance
          .collection('goal_list')
          .where('goal_name', isEqualTo: widget.event.goalName)
          .get();

      // action_history 데이터 로드
      final actionHistoryQuery = await FirebaseFirestore.instance
          .collection('action_history')
          .where('action_name', isEqualTo: widget.event.actionName)
          .get();

      return {
        'action_list': actionListQuery.docs.map((doc) => doc.data()).toList(),
        'goal_due_date': goalQuery.docs.isNotEmpty 
            ? goalQuery.docs.first.data()['due_date'] 
            : null,
        'action_histories': actionHistoryQuery.docs.map((doc) => doc.data()).toList(),
      };
    } catch (e) {
      print('Error loading initial data: $e');
      // 기본값 반환
      return {
        'action_list': [],
        'goal_due_date': null,
        'action_histories': [],
      };
    }
  }

  static const Map<String, String> statusDescriptions = {
    'scheduled': '(배정됨)',
    'delayed': '(일정변경)',
    'completed': '(완료)',
    'extended': '(시간연장)',
    'dropped': '(삭제)',
    'pending': '(평가기)',
    'transferred': '(위임)',
  };

  // 상태 관리를 위한 변수들
  String? selectedStatus;
  int selectedReminderMinutes = 30;
  bool _shouldReschedule = true;
  String? statusDescription;
  String? transferEmail;
  DateTime? selectedDateTime;
  int? extendedMinutes;
  String markdownText = '';

  // 파일 업로드 관련 변수
  List<PlatformFile> selectedFiles = [];

  // extended 관련 변수 추가
  double? selectedHours;
  bool rescheduleCalendar = false;

  // delayed 관련 변수 추가
  List<DateTime>? availableTimeSlots;
  DateTime? selectedStartTime;

  List<String> fileUrls = [];

  DateTime? selectedTransferTime;
  bool isValidEmail = false;

  // 이메일 검증 함수 추가
  bool _validateEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  // transferred 관련 위젯
  Widget _buildTransferredFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          decoration: InputDecoration(
            labelText: '이메일 주소',
            border: OutlineInputBorder(),
            errorText: transferEmail != null && !isValidEmail
                ? '유효한 이메일 주소를 입력해주세요'
                : null,
          ),
          onChanged: (value) {
            setState(() {
              transferEmail = value;
              isValidEmail = _validateEmail(value);
            });
          },
        ),
        SizedBox(height: 16),

        FutureBuilder<List<DateTime>>(
          // 캐시된 데이터 사용
          future: _cachedTimeSlots != null 
              ? Future.value(_cachedTimeSlots)
              : _getAvailableTimeSlots().then((slots) {
                  _cachedTimeSlots = slots;
                  return slots;
                }),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return CircularProgressIndicator();
            }

            return DropdownButtonFormField<DateTime>(
              value: selectedTransferTime,
              items: snapshot.data!.map((time) {
                return DropdownMenuItem(
                  value: time,
                  child: Text(DateFormat('yyyy-MM-dd HH:mm').format(time)),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedTransferTime = value;
                });
              },
              decoration: InputDecoration(
                labelText: '피드백 요청 시간',
                border: OutlineInputBorder(),
              ),
            );
          },
        ),
      ],
    );
  }


  // ActionEventTile 위젯
  Widget _buildActionEventTile() {
    return ListTile(
      title: Text(widget.event.actionName ?? ''),
      subtitle: Text(
          '일정: ${DateFormat('yyyy-MM-dd HH:mm').format(widget.event.startTime!)}'),
    );
  }

  // ActionEventAlarm 위젯
  Widget _buildActionEventAlarm() {
    final now = DateTime.now();
    final eventStart = widget.event.startTime!;
    final minutesUntilEvent = eventStart.difference(now).inMinutes;

    // 기본 알림 시간 옵션 (분 단위)
    final defaultOptions = [5, 10, 15, 30, 60, 120];

    // 이벤트 시작 시간까지 남은 시간보다 작은 옵션들만 필터링
    final availableOptions = defaultOptions
        .where((minutes) => minutes <= minutesUntilEvent)
        .map((minutes) => DropdownMenuItem(
              value: minutes,
              child: Text(
                '$minutes분 전',
                style: TextStyle(fontSize: 12),
              ),
            ))
        .toList();

    // 사용 가능한 옵션이 없거나 이벤트가 이미 시작된 경우
    if (availableOptions.isEmpty || minutesUntilEvent <= 0) {
      return Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          'Notification cannot be set (Event has started or will start soon)',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    // 현재 선택된 값이 가능한 옵션 범위를 벗어나면 첫 번째 옵션으로 설정
    if (!defaultOptions.contains(selectedReminderMinutes) ||
        selectedReminderMinutes > minutesUntilEvent) {
      selectedReminderMinutes = availableOptions.first.value!;
    }

    return DropdownButtonFormField<int>(
      value: selectedReminderMinutes,
      items: availableOptions,
      onChanged: (value) => setState(() => selectedReminderMinutes = value!),
      decoration: InputDecoration(
        labelText: '알림 설정',
        border: OutlineInputBorder(),
      ),
    );
  }

  // ActionEventStatus 위젯
  Widget _buildActionEventStatus() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          value: selectedStatus,
          items: statusDescriptions.entries.map((entry) {
            return DropdownMenuItem<String>(
              value: entry.key,
              child: Text(
                entry.key,
                style: TextStyle(fontSize: 12),
              ),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              selectedStatus = value;
              // 상태에 따른 추가 위젯 표시 여부 설정
            });
          },
          decoration: InputDecoration(
            labelText: '상태 변경',
            border: OutlineInputBorder(),
          ),
        ),
        if (selectedStatus != null)
          Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              statusDescriptions[selectedStatus!] ?? '',
              style: TextStyle(color: Colors.green, fontSize: 12),
            ),
          ),
      ],
    );
  }

  // ActionEventDescription 위젯
  Widget _buildActionEventDescription() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _descriptionController,
          maxLines: 5,
          decoration: InputDecoration(
            labelText: '상태 설명',
            border: OutlineInputBorder(),
            hintText: '마크다운 형식으로 작성할 수 있습니다',
            hintStyle: TextStyle(fontSize: 12),
            labelStyle: TextStyle(fontSize: 14),
          ),
          onChanged: (value) => setState(() => markdownText = value),
        ),
        if (markdownText.isNotEmpty) ...[
          SizedBox(height: 16),
          Text(
            '미리보기',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          SizedBox(height: 8),
          Container(
            width: double.infinity,
            height: 200,
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey.shade50,
            ),
            child: SingleChildScrollView(
              child: SizedBox(
                width: double.infinity,
                child: MarkdownBody(
                  data: markdownText,
                  styleSheet: MarkdownStyleSheet(
                    p: TextStyle(fontSize: 14),
                    code: TextStyle(
                      backgroundColor: Colors.grey.shade200,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  // 이메일 입력 위젯
  Widget _buildEmailInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          decoration: InputDecoration(
            labelText: '이메일 주소',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) {
            setState(() {
              transferEmail = value;
              // 이메일 형식 검증
              final bool isValid =
                  RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value);
              if (!isValid) {
                statusDescription = '유효한 이메일 주소를 입력해주세요';
              } else {
                statusDescription = null;
              }
            });
          },
        ),
        if (statusDescription != null)
          Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              statusDescription!,
              style: TextStyle(color: Colors.orange, fontSize: 12),
            ),
          ),
      ],
    );
  }

  // 시간 선택 위젯
  Widget _buildTimeSelect() {
    return DropdownButtonFormField<int>(
      value: extendedMinutes ?? 30,
      items: [30, 60, 90, 120, 150, 180, 210, 240].map((minutes) {
        return DropdownMenuItem(
          value: minutes,
          child: Text('$minutes분'),
        );
      }).toList(),
      onChanged: (value) => setState(() => extendedMinutes = value),
      decoration: InputDecoration(
        labelText: '연장 시간',
        border: OutlineInputBorder(),
      ),
    );
  }

  // extended 시간 선택 위젯
  Widget _buildExtendedTimeSelect() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<double>(
          value: selectedHours,
          items: [1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0].map((hours) {
            return DropdownMenuItem(
              value: hours,
              child: Text('${hours.toString()}시간'),
            );
          }).toList(),
          onChanged: (value) => setState(() => selectedHours = value),
          decoration: InputDecoration(
            labelText: '연장 시간',
            border: OutlineInputBorder(),
            hintText: '연장 시간을 선택하세요',
          ),
        ),
        SizedBox(height: 16),
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, size: 20, color: Colors.grey.shade700),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  '캘린더 전체 일정이 자동으로 재조정됩니다',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 이미지 회전 기능 추가
  int _rotationAngle = 0;  // 추가
  void _rotateImage() {
    setState(() {
      _rotationAngle = (_rotationAngle + 90) % 360;
    });
  }

  // 이미지 리사이즈 함수
  Future<Uint8List> _resizeImage(Uint8List imageData) async {
    final image = img.decodeImage(imageData);
    if (image == null) return imageData;

    // 이미지 크기를 1MB 이하로 조정
    int quality = 100;
    Uint8List resizedImageData;
    do {
      resizedImageData = Uint8List.fromList(img.encodeJpg(image, quality: quality));
      quality -= 10;
    } while (resizedImageData.lengthInBytes > 1024 * 1024 && quality > 0);

    return resizedImageData;
  }


  // ActionEventUploadImage 위젯
  Widget _buildActionEventUploadImage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          leading: Icon(Icons.image),
          title: Text(
            '이미지 업로드',
            style: TextStyle(fontSize: 14),
          ),
          trailing: IconButton(
            icon: Icon(Icons.add_photo_alternate),
            onPressed: () async {
              final ImagePicker picker = ImagePicker();
              final XFile? image = await picker.pickImage(source: ImageSource.gallery);

              if (image != null) {
                // 이미지 선택 시 바로 리사이즈 및 인코딩 수행
                final imageBytes = await image.readAsBytes();
                final resizedImageBytes = await _resizeImage(imageBytes);
                _encodedImage = base64Encode(resizedImageBytes);

                setState(() {
                  selectedImages.clear();
                  imageUrls.clear();
                  selectedImages.add(image);
                  selectedImagePurpose = null;
                });
              }
            },
          ),
        ),
        if (selectedImages.isNotEmpty)
          Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: InteractiveViewer(
                      panEnabled: true,
                      boundaryMargin: EdgeInsets.all(20),
                      minScale: 0.5,
                      maxScale: 2.0,
                      child: Transform.rotate(
                        angle: _rotationAngle * (3.141592653589793 / 180),
                        child: Container(
                          width: 200,
                          height: 200,
                          child: Image.network(
                            selectedImages.first.path,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  Column(
                    children: [
                      ElevatedButton(
                        onPressed: _rotateImage,
                        child: Text('이미지 회전'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: Size(120, 36),
                        ),
                      ),
                      SizedBox(height: 16),
                      Divider(height: 1, thickness: 1),
                      SizedBox(height: 16),
                      ToggleButtons(
                        constraints: BoxConstraints.expand(
                          width: 60,
                          height: 36,
                        ),
                        borderColor: Colors.grey,
                        selectedBorderColor: Colors.blue,
                        fillColor: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        children: [
                          Tooltip(
                            message: 'save history image',
                            child: Icon(Icons.save, color: Colors.blue, size: 20),
                          ),
                          Tooltip(
                            message: 'analyze image to text',
                            child: Icon(Icons.text_fields, color: Colors.blue, size: 20),
                          ),
                        ],
                        isSelected: [
                          selectedImagePurpose == 'purpose1',
                          selectedImagePurpose == 'purpose2'
                        ],
                        onPressed: (index) {
                          setState(() {
                            selectedImagePurpose = index == 0 ? 'purpose1' : 'purpose2';
                          });
                        },
                      ),
                      SizedBox(height: 16),
                      if (selectedImagePurpose == 'purpose2')
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            minimumSize: Size(120, 36),
                          ),
                          onPressed: _isAnalyzing ? null : () async {
                            setState(() {
                              _isAnalyzing = true;
                            });
                            
                            try {
                              await _analyzeImage();
                            } finally {
                              if (mounted) {
                                setState(() {
                                  _isAnalyzing = false;
                                });
                              }
                            }
                          },
                          child: _isAnalyzing
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text('AI 분석', style: TextStyle(fontSize: 14)),
                        ),
                    ],
                  ),
                ],
              ),
            ],
          ),
      ],
    );
  }

  // 이미지 분석을 위한 API 호출 메서드
  Future<void> _analyzeImage() async {
    setState(() {
      _isAnalyzing = true;
    });

    try {
      if (_encodedImage == null) {
        throw Exception('인코딩된 이미지가 없습니다.');
      }

      final requestBody = {
        'goal_name': widget.event.goalName,
        'action_name': widget.event.actionName,
        'action_target_time': widget.event.startTime?.toIso8601String(),
        'related_action_list': (_cachedData?['action_list'] as List)
            .map((item) => convertTimestampFields(item))
            .toList(),
        'send_email': transferEmail,
        'action_history': (_cachedData?['action_histories'] as List)
            .map((item) => convertTimestampFields(item))
            .toList(),
        'image': _encodedImage,
      };

      final response = await http.post(
        Uri.parse('https://shsong83.app.n8n.cloud/webhook/timetrek-image-to-text'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        String content = responseData['content'] as String? ?? '';
        
        // 코드 블록 마커 제거
        content = content.replaceAll('```markdown\n', '')
                        .replaceAll('\n```', '');
        
        // 기존 텍스트에 새로운 내용 추가
        final newText = _descriptionController.text.isEmpty 
            ? content 
            : '${_descriptionController.text}\n\n$content';
        
        setState(() {
          markdownText = newText;
          _descriptionController.text = newText;
          _descriptionController.selection = TextSelection.fromPosition(
            TextPosition(offset: newText.length),
          );
        });
      } else {
        throw Exception('이미지 분석 실패: ${response.statusCode}');
      }
    } catch (e) {
      print('이미지 분석 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('이미지 분석 중 오류가 발생했습니다: $e')),
      );
    } finally {
      setState(() {
        _isAnalyzing = false;
      });
    }
  }

  // ActionEventUploadFile 위젯
  Widget _buildActionEventUploadFile() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          leading: Icon(Icons.attach_file),
          title: Text(
            '파일 업로드',
            style: TextStyle(fontSize: 14),
          ),
          trailing: IconButton(
            icon: Icon(Icons.add_box),
            onPressed: () async {
              // action_list에서 reference_file_count 확인
              final actionListQuery = await FirebaseFirestore.instance
                  .collection('action_list')
                  .where('action_name', isEqualTo: widget.event.actionName)
                  .get();

              if (actionListQuery.docs.isEmpty) return;

              final currentCount =
                  actionListQuery.docs.first.data()['reference_file_count'] ??
                      0;

              if (currentCount >= AppState.actionMaxFileCount) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('파일 업로드 제한 횟수를 초과했습니다.')),
                );
                return;
              }

              FilePickerResult? result = await FilePicker.platform.pickFiles();

              if (result != null) {
                final file = result.files.first;
                final fileSizeInMB = file.size / (1024 * 1024);

                if (fileSizeInMB > AppState.actionLimitFileMBSize) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('파일 크기가 제한을 초과했습니다.')),
                  );
                  return;
                }

                setState(() {
                  selectedFiles.add(file);
                });
              }
            },
          ),
        ),
        if (selectedFiles.isNotEmpty)
          Column(
            children: selectedFiles.map((file) {
              return ListTile(
                title: Text(file.name),
                trailing: IconButton(
                  icon: Icon(Icons.close),
                  onPressed: () {
                    setState(() {
                      selectedFiles.remove(file);
                    });
                  },
                ),
              );
            }).toList(),
          ),
      ],
    );
  }
  // delayed 시간 선택 위젯
  Widget _buildDelayedTimeSelect() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            children: [
              // 날짜 선택 섹션
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: InkWell(
                  onTap: () async {
                    final selectedDate = await showDatePicker(
                      context: context,
                      initialDate: selectedStartTime ?? DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                      builder: (context, child) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: ColorScheme.light(
                              primary: Theme.of(context).primaryColor,
                              onPrimary: Colors.white,
                            ),
                          ),
                          child: child!,
                        );
                      },
                    );

                    if (selectedDate != null) {
                      // 선택된 날짜의 시작 시간으로 초기화
                      setState(() {
                        selectedStartTime = DateTime(
                          selectedDate.year,
                          selectedDate.month,
                          selectedDate.day,
                        );
                      });
                    }
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        selectedStartTime != null
                            ? DateFormat('yyyy년 MM월 dd일')
                                .format(selectedStartTime!)
                            : '날짜 선택',
                        style: const TextStyle(fontSize: 16),
                      ),
                      const Icon(Icons.calendar_today),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1),
              // 시간 선택 섹션
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                ),
                child: selectedStartTime == null
                    ? const Text('날짜를 먼저 선택해주세요')
                    : FutureBuilder<List<DateTime>>(
                        future: _getAvailableTimeSlots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const Center(child: CircularProgressIndicator());
                          }

                          // 선택된 날짜에 해당하는 시간대만 필터링
                          final timeSlots = snapshot.data!
                              .where((slot) =>
                                  slot.year == selectedStartTime!.year &&
                                  slot.month == selectedStartTime!.month &&
                                  slot.day == selectedStartTime!.day)
                              .toList()
                            ..sort();

                          if (timeSlots.isEmpty) {
                            return const Text('선택한 날짜에 사용 가능한 시간대가 없습니다');
                          }

                          // 현재 선택된 시간이 없거나 유효하지 않은 경우 첫 번째 시간대로 설정
                          if (selectedStartTime == null || 
                              !timeSlots.contains(selectedStartTime)) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              setState(() {
                                selectedStartTime = timeSlots.first;
                              });
                            });
                            return const Center(child: CircularProgressIndicator());
                          }

                          return DropdownButtonFormField<DateTime>(
                            value: selectedStartTime,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                            ),
                            items: timeSlots.map((time) {
                              return DropdownMenuItem<DateTime>(
                                value: time,
                                child: Text(DateFormat('HH:mm').format(time)),
                              );
                            }).toList(),
                            onChanged: (newTime) {
                              if (newTime != null) {
                                setState(() {
                                  selectedStartTime = newTime;
                                });
                              }
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
        if (selectedStartTime != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '선택된 시간: ${DateFormat('yyyy-MM-dd HH:mm').format(selectedStartTime!)}',
              style: TextStyle(
                color: Theme.of(context).primaryColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }

  // 사용 가능한 시간대 조회
  Future<List<DateTime>> _getAvailableTimeSlots() async {
    print('=== _getAvailableTimeSlots 시작 ===');
    try {
      final currentTimegroup = widget.event.timegroup;

      if (currentTimegroup == null) {
        return [];
      }

      // 시작 시간과 종료 시간을 함께 저장하는 맵
      Map<DateTime, DateTime> timeSlotRanges = {};

      // 1. timeslot 콜렉션에서 데이터 가져오기
      final timeslotQuery = await FirebaseFirestore.instance
          .collection('timeslot')
          .where('subject', isEqualTo: currentTimegroup)
          .get();
      print('timeslot 콜렉션 조회 (subject=$currentTimegroup): ${timeslotQuery.docs.length}개의 문서 로드됨');

      for (var doc in timeslotQuery.docs) {
        final startTime = doc.data()['startTime'] as Timestamp?;
        final endTime = doc.data()['endTime'] as Timestamp?;
        if (startTime != null && endTime != null) {
          timeSlotRanges[startTime.toDate()] = endTime.toDate();
          // print('timeslot 시간 범위 추가: ${startTime.toDate()} ~ ${endTime.toDate()}');
        }
      }

      // 2. timeslot_event 콜렉션에서 데이터 가져오기
      final groupNumber = currentTimegroup.split('-').last;
      final eventSubject = 'event-$groupNumber';

      final timeslotEventQuery = await FirebaseFirestore.instance
          .collection('timeslot_event')
          .where('subject', isEqualTo: eventSubject)
          .get();
      print('timeslot_event 콜렉션 조회 (subject=$eventSubject): ${timeslotEventQuery.docs.length}개의 문서 로드됨');

      for (var doc in timeslotEventQuery.docs) {
        final startTime = doc.data()['startTime'] as Timestamp?;
        final endTime = doc.data()['endTime'] as Timestamp?;
        if (startTime != null && endTime != null) {
          timeSlotRanges[startTime.toDate()] = endTime.toDate();
          // print('timeslot_event 시간 범위 추가: ${startTime.toDate()} ~ ${endTime.toDate()}');
        }
      }

      // 수집된 시간대를 30분 단위로 확장하되, endTime을 고려
      Set<DateTime> expandedTimeSlots = {};
      for (var entry in timeSlotRanges.entries) {
        DateTime currentTime = entry.key;
        final endTime = entry.value;

        // 각 시간대에 대해 endTime까지만 30분 간격으로 시간대 생성
        while (currentTime.isBefore(endTime)) {
          expandedTimeSlots.add(currentTime);
          currentTime = currentTime.add(Duration(minutes: 30));
        }
      }

      // 현재 시간 이후의 시간대만 필터링하고 정렬
      final now = DateTime.now();
      final availableSlots = expandedTimeSlots
          .where((time) => time.isAfter(now))
              .toList()
            ..sort((a, b) => a.compareTo(b));

      // print('사용 가능한 시간대 수: ${availableSlots.length}개');
      // print('=== _getAvailableTimeSlots 종료 ===');

      return availableSlots;
    } catch (e) {
      print('Error in _getAvailableTimeSlots: $e');
      return [];
    }
  }

  // 저장 로직 수정
  Future<void> _handleSave() async {
    try {
      if (selectedStatus == 'extended') {
        if (selectedHours == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('연장 시간을 선택해주세요')),
          );
          return;
        }
        rescheduleCalendar = true;
        await _handleExtended();
      }
      // transferred 상태 처리를 먼저 수행
      else if (selectedStatus == 'transferred') {
        if (!isValidEmail || selectedTransferTime == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('이메일과 시간을 모두 올바르게 입력해주세요')),
          );
          return;
        }
        await _handleTransferred(); // 이메일 전송 처리
        
        // calendar_event 업데이트
        await widget.event.reference.update({
          'action_status': 'transferred',
        });

        // action_list 업데이트
        final actionListQuery = await FirebaseFirestore.instance
            .collection('action_list')
            .where('action_name', isEqualTo: widget.event.actionName)
            .get();

        if (actionListQuery.docs.isNotEmpty) {
          await actionListQuery.docs.first.reference.update({
            'action_status': 'transferred',
            'transfer_email': transferEmail,
            'transfer_time': selectedTransferTime,
          });
        }
      }
      // pending 상태 처리 추가
      else if (selectedStatus == 'pending') {
        await _handlePending();
      }
      // dropped 상태 처리
      else if (selectedStatus == 'dropped') {
        await _handleDrop();
      }
      // completed 상태 처리
      else if (selectedStatus == 'completed') {
        await _handleCompleted();
      }

      // action_history 생성
      await _createActionHistory();

      // UI 업데이트 및 화면 닫기
      widget.refreshController.add(null);

      // 상태 업데이트를 위해 setState 호출
      if (mounted) {
        setState(() {});
      }

      // 화면 닫기 전에 짧은 지연 추가
      await Future.delayed(const Duration(milliseconds: 300));

      // 화면 닫기
      if (context.mounted) {
        Navigator.pop(context);

        // 스낵바로 성공 메시지 표시
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('변경사항이 저장되었습니다'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 중 오류가 발생했습니다: $e')),
        );
      }
    }
  }

  // action_id 조회
  Future<String> _getActionId(String actionName) async {
    final query = await FirebaseFirestore.instance
        .collection('action_list')
        .where('action_name', isEqualTo: actionName)
        .get();
    return query.docs.first.id;
  }

  bool resetCalendar = false; // 캘린더 재배치 여부

  // dropped 상태일 때 표시할 위젯
  Widget _buildDroppedFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          title: Text('캘린더 재배치'),
          subtitle: Text('Action 삭제 및 전체 일정을 재조정합니다'),
          value: resetCalendar,
          onChanged: (bool value) {
            setState(() {
              resetCalendar = value;
            });
          },
        ),
      ],
    );
  }

  Future<void> _handleDrop() async {
    print('=== _handleDrop 시작 ===');
    try {
      // 1. calendar_event에서 동일한 action_name을 가진 모든 이벤트 삭제
      final calendarEvents = await FirebaseFirestore.instance
          .collection('calendar_event')
          .where('action_name', isEqualTo: widget.event.actionName)
          .get();
      print('calendar_event 콜렉션 조회 (action_name=${widget.event.actionName}): ${calendarEvents.docs.length}개의 문서 로드됨');

      for (var doc in calendarEvents.docs) {
        await doc.reference.delete();
      }

      // 2. action_list에서 해당 액션 삭제
      final actionListQuery = await FirebaseFirestore.instance
          .collection('action_list')
          .where('action_name', isEqualTo: widget.event.actionName)
          .get();
      print('action_list 콜렉션 조회 (action_name=${widget.event.actionName}): ${actionListQuery.docs.length}개의 문서 로드됨');

      if (actionListQuery.docs.isNotEmpty) {
        await actionListQuery.docs.first.reference.delete();
      }

      // 3. action_history에서 해당 액션 관련 기록 삭제
      final actionHistoryQuery = await FirebaseFirestore.instance
          .collection('action_history')
          .where('action_name', isEqualTo: widget.event.actionName)
          .get();
      print('action_history 콜렉션 조회 (action_name=${widget.event.actionName}): ${actionHistoryQuery.docs.length}개의 문서 로드됨');

      for (var doc in actionHistoryQuery.docs) {
        await doc.reference.delete();
      }

      // 4. 캘린더 재배치 실행 (resetCalendar가 true일 때만)
      if (resetCalendar) {
        await newCalendarEvent(context);
      }
    } catch (e) {
      print('Error in _handleDrop: $e');
      rethrow;
    }
    print('=== _handleDrop 종료 ===\n');
  }

  Future<void> _handleCompleted() async {
    print('=== _handleCompleted 시작 ===');
    try {
      // 1. calendar_event 콜렉션 업데이트
      final calendarEvents = await FirebaseFirestore.instance
          .collection('calendar_event')
          .where('action_name', isEqualTo: widget.event.actionName)
          .get();
      print('calendar_event 콜렉션 조회 (action_name=${widget.event.actionName}): ${calendarEvents.docs.length}개의 문서 로드됨');

      for (var doc in calendarEvents.docs) {
        await doc.reference.update({
          'action_status': 'completed',
        });
      }

      // 2. action_list 콜렉션 업데이트
      final actionListQuery = await FirebaseFirestore.instance
          .collection('action_list')
          .where('action_name', isEqualTo: widget.event.actionName)
          .get();
      print('action_list 콜렉션 조회 (action_name=${widget.event.actionName}): ${actionListQuery.docs.length}개의 문서 로드됨');

      if (actionListQuery.docs.isNotEmpty) {
        await actionListQuery.docs.first.reference.update({
          'action_status': 'completed',
        });
      }

      // 3. 이미지 및 파일 업로드
      List<String> uploadedImageUrls = [];
      List<String> uploadedFileUrls = [];

      // 이미지 업로드
      for (var image in selectedImages) {
        final imageBytes = await image.readAsBytes();
        final imagePath =
            'action_images/${DateTime.now().millisecondsSinceEpoch}_${image.name}';
        final imageRef = FirebaseStorage.instance.ref().child(imagePath);
        await imageRef.putData(imageBytes);
        final imageUrl = await imageRef.getDownloadURL();
        uploadedImageUrls.add(imageUrl);
      }

      // 파일 업로드
      for (var file in selectedFiles) {
        final bytes = file.bytes;
        if (bytes != null) {
          final filePath =
              'action_files/${DateTime.now().millisecondsSinceEpoch}_${file.name}';
          final fileRef = FirebaseStorage.instance.ref().child(filePath);
          await fileRef.putData(bytes);
          final fileUrl = await fileRef.getDownloadURL();
          uploadedFileUrls.add(fileUrl);
        }
      }

      // 4. action_history 생성
      await FirebaseFirestore.instance.collection('action_history').add({
        'action_id': actionListQuery.docs.first.id,
        'timestamp': FieldValue.serverTimestamp(),
        'action_status': 'completed',
        'action_name': widget.event.actionName,
        'goal_name': widget.event.goalName,
        'action_execution_time': widget.event.actionExecutionTime,
        'description': markdownText,
        'attached_images': uploadedImageUrls,
        'attached_files': uploadedFileUrls,
      });
    } catch (e) {
      print('Error in _handleCompleted: $e');
      rethrow;
    }
    print('=== _handleCompleted 종료 ===\n');
  }

  Future<void> _createActionHistory() async {
    print('=== _createActionHistory 시작 ===');
    
    // action_list 조회
    final actionListQuery = await FirebaseFirestore.instance
        .collection('action_list')
        .where('action_name', isEqualTo: widget.event.actionName)
        .get();
    print('action_list 콜렉션 조회 (action_name=${widget.event.actionName}): ${actionListQuery.docs.length}개의 문서 로드됨');

    String? actionId;
    if (actionListQuery.docs.isNotEmpty) {
      actionId = actionListQuery.docs.first.id;
    }

    // action_history 생성
    await FirebaseFirestore.instance.collection('action_history').add({
      'action_id': actionId ?? '',
      'action_name': widget.event.actionName ?? '',
      'goal_name': widget.event.goalName ?? '',
      'timestamp': FieldValue.serverTimestamp(),
      'action_status': selectedStatus ?? '',
      'action_status_description': markdownText,
      'attached_file': fileUrls.isNotEmpty ? fileUrls.join(',') : '',
      'attached_image': imageUrls.isNotEmpty ? imageUrls.join(',') : '',
      'action_execution_time': widget.event.actionExecutionTime ?? 0.0,
    });
    print('=== _createActionHistory 종료 ===\n');
  }

  // pending 상태 처리를 위한 새로운 메서드 추가
  Future<void> _handlePending() async {
    try {
      // 1. calendar_event 콜렉션 업데이트
      await widget.event.reference.update({
        'action_status': 'pending',
      });

      // 2. action_list 콜렉션 업데이트
      final actionListQuery = await FirebaseFirestore.instance
          .collection('action_list')
          .where('action_name', isEqualTo: widget.event.actionName)
          .get();

      if (actionListQuery.docs.isNotEmpty) {
        await actionListQuery.docs.first.reference.update({
          'action_status': 'pending',
        });
      }

      // 3. 이미지 및 파일 업로드 (필요한 경우)
      List<String> uploadedImageUrls = [];
      List<String> uploadedFileUrls = [];

      // 이미지 업로드
      for (var image in selectedImages) {
        final imageBytes = await image.readAsBytes();
        final imagePath =
            'action_images/${DateTime.now().millisecondsSinceEpoch}_${image.name}';
        final imageRef = FirebaseStorage.instance.ref().child(imagePath);
        await imageRef.putData(imageBytes);
        final imageUrl = await imageRef.getDownloadURL();
        uploadedImageUrls.add(imageUrl);
      }

      // 파일 업로드
      for (var file in selectedFiles) {
        final bytes = file.bytes;
        if (bytes != null) {
          final filePath =
              'action_files/${DateTime.now().millisecondsSinceEpoch}_${file.name}';
          final fileRef = FirebaseStorage.instance.ref().child(filePath);
          await fileRef.putData(bytes);
          final fileUrl = await fileRef.getDownloadURL();
          uploadedFileUrls.add(fileUrl);
        }
      }

      // 4. action_history 생성
      await FirebaseFirestore.instance.collection('action_history').add({
        'action_id': actionListQuery.docs.first.id,
        'timestamp': FieldValue.serverTimestamp(),
        'action_status': 'pending',
        'action_name': widget.event.actionName,
        'goal_name': widget.event.goalName,
        'action_execution_time': widget.event.actionExecutionTime,
        'description': markdownText,
        'attached_images': uploadedImageUrls,
        'attached_files': uploadedFileUrls,
      });
    } catch (e) {
      print('Error in _handlePending: $e');
      rethrow;
    }
  }

  // extended 상태 처리를 위한 새로운 메서드
  Future<void> _handleExtended() async {
    try {
      // 1. 현재 이벤트의 종료 시간을 연장
      final newEndTime = widget.event.endTime!
          .add(Duration(minutes: (selectedHours! * 60).round()));

      // 2. calendar_event 업데이트
      await widget.event.reference.update({
        'action_status': 'extended',
        'end_time': newEndTime,
      });

      // 3. action_list 업데이트
      final actionListQuery = await FirebaseFirestore.instance
          .collection('action_list')
          .where('action_name', isEqualTo: widget.event.actionName)
          .get();

      if (actionListQuery.docs.isNotEmpty) {
        await actionListQuery.docs.first.reference.update({
          'action_status': 'extended',
          'action_execution_time':
              widget.event.actionExecutionTime! + selectedHours!,
        });

        // 4. action_history에 직접 로그 생성
        await FirebaseFirestore.instance.collection('action_history').add({
          'action_id': actionListQuery.docs.first.id,
          'timestamp': FieldValue.serverTimestamp(),
          'action_status': 'extended',
          'action_name': widget.event.actionName,
          'goal_name': widget.event.goalName,
          'action_execution_time':
              widget.event.actionExecutionTime! + selectedHours!,
          'description': markdownText,
          'extended_hours': selectedHours,
          'original_end_time': widget.event.endTime,
          'new_end_time': newEndTime,
        });
      }

      // 5. 캘린더 재배치가 선택된 경우
      if (rescheduleCalendar) {
        await newCalendarEvent(context);
      }
    } catch (e) {
      print('Error in _handleExtended: $e');
      rethrow;
    }
  }

  // transferred 상태 처리를 위한 메서드 수정
  Future<void> _handleTransferred() async {
    print('=== _handleTransferred 시작 ===');
    try {
      if (_cachedData == null) {
        throw Exception('초기 데이터가 로드되지 않았습니다.');
      }

      // Timestamp를 ISO 문자열로 변환하는 헬퍼 함수
      dynamic convertTimestampFields(dynamic value) {
        if (value is Timestamp) {
          return value.toDate().toIso8601String();
        } else if (value is Map) {
          return value.map((key, val) => MapEntry(key, convertTimestampFields(val)));
        } else if (value is List) {
          return value.map((val) => convertTimestampFields(val)).toList();
        }
        return value;
      }

      // 전체 데이터의 깊은 복사본 생성 및 Timestamp 변환
      final actionList = (_cachedData!['action_list'] as List).map((item) {
        print('변환 전 action_list 항목: $item');
        final convertedItem = convertTimestampFields(item);
        print('변환 후 action_list 항목: $convertedItem');
        return convertedItem;
      }).toList();

      final actionHistories = (_cachedData!['action_histories'] as List).map((item) {
        print('변환 전 action_histories 항목: $item');
        final convertedItem = convertTimestampFields(item);
        print('변환 후 action_histories 항목: $convertedItem');
        return convertedItem;
      }).toList();

      // 요청 본문 생성 전 모든 필드 검사
      final requestBody = {
        'goal_name': widget.event.goalName,
        'action_name': widget.event.actionName,
        'action_target_time': selectedTransferTime?.toIso8601String(),
        'related_action_list': actionList,
        'send_email': transferEmail,
        'action_history': actionHistories,
      };

      // 요청 본문의 모든 필드를 Timestamp 변환
      final convertedRequestBody = convertTimestampFields(requestBody);
      
      print('변환된 API 요청 데이터:');
      final jsonString = jsonEncode(convertedRequestBody);
      print(jsonString);

      final response = await http.post(
        Uri.parse('https://shsong83.app.n8n.cloud/webhook-test/send-email-action-transferred'),
        headers: {'Content-Type': 'application/json'},
        body: jsonString,
      );

      print('API 응답 상태 코드: ${response.statusCode}');
      print('API 응답 본문: ${response.body}');

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$transferEmail로 성공적으로 전송되었습니다.'), backgroundColor: Colors.green),
          );
        }
      } else {
        throw Exception('API 호출 실패: ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      print('전송 실패: ${e.toString()}');
      print('스택 트레이스: $stackTrace');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('전송 실패: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    }
    print('=== _handleTransferred 종료 ===\n');
  }

  // Timestamp 변환 헬퍼 함수 추가
  dynamic convertTimestampFields(dynamic value) {
    if (value is Timestamp) {
      return value.toDate().toIso8601String();
    } else if (value is Map) {
      return value.map((key, val) => MapEntry(key, convertTimestampFields(val)));
    } else if (value is List) {
      return value.map((val) => convertTimestampFields(val)).toList();
    }
    return value;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _initialDataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('데이터 로드 실패: ${snapshot.error}'));
        }

        _cachedData = snapshot.data;

        return Container(
          padding: EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildActionEventTile(),
                SizedBox(height: 16),
                _buildActionEventAlarm(),
                SizedBox(height: 16),
                _buildActionEventStatus(),
                SizedBox(height: 16),
                if (selectedStatus == 'transferred') _buildTransferredFields(),
                if (selectedStatus == 'extended') _buildExtendedTimeSelect(),
                if (selectedStatus == 'delayed') _buildDelayedTimeSelect(),
                if (selectedStatus == 'dropped') _buildDroppedFields(),
                _buildActionEventUploadImage(),
                SizedBox(height: 16),
                _buildActionEventUploadFile(),
                SizedBox(height: 16),
                _buildActionEventDescription(),
                SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('취소'),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      onPressed: _canSave() ? _handleSave : null,
                      child: Text('저장'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // 저장 가능 여부 확인
  bool _canSave() {
    if (selectedStatus == 'extended' && selectedHours == null) {
      return false;
    }
    return true;
  }
}

