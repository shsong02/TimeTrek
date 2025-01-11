import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'dart:html' as html;
import '/theme/time_trek_theme.dart';
import '../models/action_event_data.dart';

class EmailReportWidget extends StatefulWidget {
  final String reportType;
  final List<ActionEventData> actionEvents;
  final List<String> selectedTags;
  final bool hideCompleted;
  final DateTime startTime;
  final DateTime endTime;

  const EmailReportWidget({
    Key? key,
    required this.reportType,
    required this.actionEvents,
    required this.selectedTags,
    required this.hideCompleted,
    required this.startTime,
    required this.endTime,
  }) : super(key: key);

  @override
  State<EmailReportWidget> createState() => _EmailReportWidgetState();
}

class _EmailReportWidgetState extends State<EmailReportWidget> {
  final _emailController = TextEditingController();
  bool _isSending = false;
  bool _isExpanded = false;
  String? _analysisResult;
  final now = DateTime.now();

  String escapeHtml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#039;');
  }

  Future<void> _sendEmail() async {
    if (!_emailController.text.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('유효한 이메일 주소를 입력해주세요')),
      );
      return;
    }

    setState(() => _isSending = true);

    try {
      print('이메일 리포트 생성 시작...');
      final htmlContent = await _generateHtmlReport();

      if (htmlContent == null) {
        print('HTML 리포트 생성 실패');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('리포트 생성 중 오류가 발생했습니다')),
          );
        }
        return;
      }

      print('HTML 리포트 생성 완료, API 호출 시작...');
      final url = Uri.parse(
          'https://shsong83.app.n8n.cloud/webhook/timetrek-goal-evaluation');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'to': _emailController.text,
          'subject':
              '${widget.reportType == 'daily' ? '[TimeTrek] 일간' : widget.reportType == 'weekly' ? '[TimeTrek] 주간' : '[TimeTrek] 월간'} 목표 평가 리포트',
          'html': htmlContent,
          'only_email': true,
        }),
      );

      print('API 응답 상태 코드: ${response.statusCode}');
      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('리포트가 이메일로 전송되었습니다')),
          );
        }
      } else {
        print('API 오류 응답: ${response.body}');
        throw Exception('이메일 전송 실패');
      }
    } catch (e) {
      print('이메일 전송 중 오류 발생: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('이메일 전송 중 오류가 발생했습니다')),
        );
      }
    } finally {
      setState(() => _isSending = false);
    }
  }

  Future<String?> _generateHtmlReport() async {
    try {
      // 데이터 준비
      final filteredEvents = widget.actionEvents
          .where((e) =>
              e.startTime.isAfter(widget.startTime) &&
              e.endTime.isBefore(widget.endTime) &&
              (widget.selectedTags.isEmpty ||
                  widget.selectedTags.any((tag) => e.tags.contains(tag))) &&
              (!widget.hideCompleted || e.actionStatus != 'completed'))
          .toList();

      // AI 분석 결과 가져오기
      String aiAnalysis = '';
      try {
        final storageKey = 'ai_analysis_${widget.reportType}';
        final savedData = html.window.localStorage[storageKey];

        if (savedData != null) {
          final data = jsonDecode(savedData);
          final output = data['parsed'] as Map<String, dynamic>;

          switch (widget.reportType) {
            case 'daily':
              aiAnalysis = _generateDailyAnalysis(output);
              break;
            case 'weekly':
              aiAnalysis = _generateWeeklyAnalysis(output);
              break;
            case 'monthly':
              aiAnalysis = _generateMonthlyAnalysis(output);
              break;
          }
        } else {
          aiAnalysis = _generateEmptyAnalysis();
        }
      } catch (e) {
        print('저장된 AI 분석 결과 가져오기 실패: $e');
        aiAnalysis = _generateErrorAnalysis();
      }

      // 리포트 타입별 제목 설정
      String reportTitle = '';
      switch (widget.reportType) {
        case 'daily':
          reportTitle =
              '일간 목표 평가 리포트 (${DateFormat('yyyy년 MM월 dd일').format(widget.startTime)})';
          break;
        case 'weekly':
          reportTitle =
              '주간 목표 평가 리포트 (${DateFormat('MM/dd').format(widget.startTime)} - ${DateFormat('MM/dd').format(widget.endTime)})';
          break;
        case 'monthly':
          reportTitle =
              '월간 목표 평가 리포트 (${DateFormat('yyyy년 MM월').format(widget.startTime)})';
          break;
      }

      // 공통 스타일 부분은 유지
      final reportHtml = '''
        <!DOCTYPE html>
        <html lang="ko">
        <head>
          <meta charset="UTF-8">
          <title>$reportTitle</title>
          <style>
            body { 
              font-family: -apple-system, BlinkMacSystemFont, sans-serif; 
              line-height: 1.6; 
              color: #333; 
              margin: 0;
              padding: 20px;
              background-color: #f5f5f5;
            }
            .container {
              max-width: 800px;
              margin: 0 auto;
            }
            .card {
              background: #fff;
              border-radius: 8px;
              box-shadow: 0 2px 4px rgba(0,0,0,0.1);
              margin-bottom: 20px;
              padding: 20px;
            }
            .section-title {
              color: #333;
              border-bottom: 2px solid #eee;
              padding-bottom: 10px;
              margin-bottom: 20px;
            }
            .progress-container {
              margin: 20px 0;
            }
            .progress-bar {
              background: #e0e0e0;
              border-radius: 4px;
              height: 20px;
              overflow: hidden;
            }
            .progress-fill {
              background: #4CAF50;
              height: 100%;
              transition: width 0.3s ease;
            }
            .stats-grid {
              display: grid;
              grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
              gap: 20px;
              margin: 20px 0;
            }
            .stat-card {
              background: #f8f9fa;
              padding: 15px;
              border-radius: 8px;
              text-align: center;
            }
            .ai-analysis h3 {
              color: #2196F3;
              margin-top: 20px;
              margin-bottom: 10px;
            }
            .ai-analysis p {
              color: #666;
              margin-bottom: 15px;
              line-height: 1.6;
            }
          </style>
        </head>
        <body>
          <div class="container">
            <h1 style="text-align: center; color: #2196F3;">$reportTitle</h1>
            
            <!-- AI 분석 결과 -->
            $aiAnalysis
            
            <!-- 진행 상황 요약 -->
            <div class="card">
              <h2 class="section-title">진행 상황 요약</h2>
              ${_generateProgressSummary(filteredEvents)}
            </div>

            <!-- 시간대별 실행 시간 -->
            <div class="card">
              <h2 class="section-title">시간대별 실행 시간</h2>
              ${_generateTimeTable(filteredEvents)}
            </div>

            <!-- 리포트 타입별 추가 섹션 -->
            ${_generateTypeSpecificSections(filteredEvents)}
          </div>
        </body>
        </html>
      ''';

      return reportHtml;
    } catch (e) {
      print('HTML 리포트 생성 중 오류: $e');
      return null;
    }
  }

  String _generateProgressSummary(List<ActionEventData> events) {
    final completedCount =
        events.where((e) => e.actionStatus == 'completed').length;
    final totalCount = events.length;
    final progress = totalCount > 0 ? (completedCount / totalCount * 100) : 0;

    return '''
      <div class="progress-container">
        <div class="progress-bar">
          <div class="progress-fill" style="width: ${progress}%"></div>
        </div>
        <p style="text-align: center;">
          전체 진행률: ${progress.toStringAsFixed(1)}% ($completedCount/$totalCount)
        </p>
      </div>
      
      <div class="stats-grid">
        <div class="stat-card">
          <h3>전체 액션</h3>
          <p style="font-size: 24px; font-weight: bold;">$totalCount개</p>
        </div>
        <div class="stat-card">
          <h3>완료된 액션</h3>
          <p style="font-size: 24px; font-weight: bold;">$completedCount개</p>
        </div>
      </div>
    ''';
  }

  String _generateTimeTable(List<ActionEventData> events) {
    return '''
      <div style="display: flex; justify-content: space-between; margin-bottom: 20px;">
        <div style="flex: 1;">
          <table style="width: 100%; border-collapse: collapse;">
            <tr style="background-color: #f5f5f5;">
              ${widget.reportType != 'daily' ? '<th style="padding: 12px; text-align: left; border: 1px solid #ddd;">날짜</th>' : ''}
              <th style="padding: 12px; text-align: left; border: 1px solid #ddd;">시간</th>
              <th style="padding: 12px; text-align: left; border: 1px solid #ddd;">업무</th>
            </tr>
            ${([
      ...events
    ]..sort((a, b) => a.startTime.compareTo(b.startTime))).map((e) => '''
              <tr>
                ${widget.reportType != 'daily' ? '<td style="padding: 12px; border: 1px solid #ddd;">${DateFormat('MM/dd').format(e.startTime)}</td>' : ''}
                <td style="padding: 12px; border: 1px solid #ddd;">
                  ${DateFormat('HH:mm').format(e.startTime)} - ${DateFormat('HH:mm').format(e.endTime)}
                </td>
                <td style="padding: 12px; border: 1px solid #ddd;">${escapeHtml(e.actionName)}</td>
              </tr>
            ''').join('')}
          </table>
        </div>
      </div>
    ''';
  }

  String _generateTypeSpecificSections(List<ActionEventData> events) {
    switch (widget.reportType) {
      case 'daily':
        return _generateDailySpecificSections(events);
      case 'weekly':
        return _generateWeeklySpecificSections(events);
      case 'monthly':
        return _generateMonthlySpecificSections(events);
      default:
        return '';
    }
  }

  String _generateDailySpecificSections(List<ActionEventData> events) {
    return '''
      <div class="card">
        <h2 class="section-title">오늘의 액션 목록</h2>
        ${_generateActionList(events)}
      </div>
    ''';
  }

  String _generateWeeklySpecificSections(List<ActionEventData> events) {
    // 일별 진행 상황 추가
    final dailyProgress = _generateDailyProgressChart(events);
    return '''
      <div class="card">
        <h2 class="section-title">일별 진행 상황</h2>
        $dailyProgress
      </div>
      <div class="card">
        <h2 class="section-title">주간 액션 목록</h2>
        ${_generateActionList(events)}
      </div>
    ''';
  }

  String _generateMonthlySpecificSections(List<ActionEventData> events) {
    // 주별 진행 상황 추가
    final weeklyProgress = _generateWeeklyProgressChart(events);
    return '''
      <div class="card">
        <h2 class="section-title">주별 진행 상황</h2>
        $weeklyProgress
      </div>
      <div class="card">
        <h2 class="section-title">월간 액션 목록</h2>
        ${_generateActionList(events)}
      </div>
    ''';
  }

  String _generateActionList(List<ActionEventData> events) {
    return '''
      <div style="max-height: 500px; overflow-y: auto;">
        ${events.map((e) => '''
          <div style="padding: 12px; border-bottom: 1px solid #eee; display: flex; align-items: center;">
            <span style="margin-right: 12px; font-size: 20px;">
              ${e.actionStatus == 'completed' ? '✅' : '⬜️'}
            </span>
            <div>
              <strong>${escapeHtml(e.actionName)}</strong>
              <br>
              <small style="color: #666;">
                ${escapeHtml(e.goalName)}
                ${e.tags.isNotEmpty ? '<br>태그: ${escapeHtml(e.tags.join(", "))}' : ''}
              </small>
            </div>
          </div>
        ''').join('')}
      </div>
    ''';
  }

  String _convertToHtml(String text) {
    text = escapeHtml(text);

    // ### 제목 변환
    text = text.replaceAllMapped(
        RegExp(r'###\s*([^\n]+)'), (match) => '<h3>${match[1]}</h3>');

    // 줄바꿈 처리
    text = text.replaceAll('\n', '<br>');

    return text;
  }

  String _generateDailyAnalysis(Map<String, dynamic> output) {
    return '''
      <div class="card">
        <h2 class="section-title">AI 분석</h2>
        <div class="ai-analysis">
          <div class="analysis-section">
            <h3>오늘의 요약</h3>
            <p>${_convertToHtml(output['today_summary'] ?? '')}</p>
          </div>
          
          <div class="analysis-section">
            <h3>주의사항</h3>
            <p>${_convertToHtml(output['today_issue_point'] ?? '')}</p>
          </div>
          
          <div class="analysis-section">
            <h3>내일의 계획</h3>
            <p>${_convertToHtml(output['tomorrow_summary'] ?? '')}</p>
          </div>
          
          <div class="analysis-section">
            <h3>주의사항</h3>
            <p>${_convertToHtml(output['tomorrow_issue_point'] ?? '')}</p>
          </div>
        </div>
      </div>
    ''';
  }

  String _generateWeeklyAnalysis(Map<String, dynamic> output) {
    return '''
      <div class="card">
        <h2 class="section-title">AI 분석</h2>
        <div class="ai-analysis">
          <div class="analysis-section">
            <h3>이번 주 요약</h3>
            <p>${_convertToHtml(output['thisweek_summary'] ?? '')}</p>
          </div>
          
          <div class="analysis-section">
            <h3>지연된 작업 및 이슈</h3>
            <p>${_convertToHtml(output['thisweek_pedning_issue'] ?? '')}</p>
          </div>
          
          <div class="analysis-section">
            <h3>완료 예상 분석</h3>
            <p>${_convertToHtml(output['thisweek_completed_estimation'] ?? '')}</p>
          </div>
          
          <div class="analysis-section">
            <h3>목표 달성 평가</h3>
            <p>${_convertToHtml(output['thisweek_goal_evaluation'] ?? '')}</p>
          </div>
        </div>
      </div>
    ''';
  }

  String _generateMonthlyAnalysis(Map<String, dynamic> output) {
    return '''
      <div class="card">
        <h2 class="section-title">AI 분석</h2>
        <div class="ai-analysis">
          <div class="analysis-section">
            <h3>월간 요약</h3>
            <p>${_convertToHtml(output['monthly_summary'] ?? '')}</p>
          </div>
          
          <div class="analysis-section">
            <h3>주요 성과</h3>
            <p>${_convertToHtml(output['key_achievements'] ?? '')}</p>
          </div>
          
          <div class="analysis-section">
            <h3>다음 달 목표</h3>
            <p>${_convertToHtml(output['next_month_goals'] ?? '')}</p>
          </div>
        </div>
      </div>
    ''';
  }

  String _generateEmptyAnalysis() {
    return '''
      <div class="card">
        <h2 class="section-title">AI 분석</h2>
        <p style="color: #666;">AI 분석 결과가 없습니다. AI 분석을 먼저 실행해주세요.</p>
      </div>
    ''';
  }

  String _generateErrorAnalysis() {
    return '''
      <div class="card">
        <h2 class="section-title">AI 분석</h2>
        <p style="color: #666;">저장된 AI 분석 결과를 가져오는 중 오류가 발생했습니다.</p>
      </div>
    ''';
  }

  String _generateDailyProgressChart(List<ActionEventData> events) {
    // 일별로 이벤트 그룹화
    final dailyEvents = <DateTime, List<ActionEventData>>{};
    for (var event in events) {
      final date = DateTime(
          event.startTime.year, event.startTime.month, event.startTime.day);
      dailyEvents.putIfAbsent(date, () => []).add(event);
    }

    return '''
      <div style="margin: 20px 0;">
        ${dailyEvents.entries.map((entry) {
      final completedCount =
          entry.value.where((e) => e.actionStatus == 'completed').length;
      final totalCount = entry.value.length;
      final progress = totalCount > 0 ? (completedCount / totalCount * 100) : 0;

      return '''
            <div style="margin: 10px 0;">
              <div style="display: flex; justify-content: space-between; margin-bottom: 5px;">
                <span>${DateFormat('MM/dd').format(entry.key)}</span>
                <span>${progress.toStringAsFixed(1)}%</span>
              </div>
              <div class="progress-bar">
                <div class="progress-fill" style="width: ${progress}%"></div>
              </div>
            </div>
          ''';
    }).join('')}
      </div>
    ''';
  }

  String _generateWeeklyProgressChart(List<ActionEventData> events) {
    // 주별로 이벤트 그룹화
    final weeklyEvents = <int, List<ActionEventData>>{};
    for (var event in events) {
      final weekNumber = (event.startTime.day - 1) ~/ 7 + 1;
      weeklyEvents.putIfAbsent(weekNumber, () => []).add(event);
    }

    return '''
      <div style="margin: 20px 0;">
        ${weeklyEvents.entries.map((entry) {
      final completedCount =
          entry.value.where((e) => e.actionStatus == 'completed').length;
      final totalCount = entry.value.length;
      final progress = totalCount > 0 ? (completedCount / totalCount * 100) : 0;

      return '''
            <div style="margin: 10px 0;">
              <div style="display: flex; justify-content: space-between; margin-bottom: 5px;">
                <span>${entry.key}주차</span>
                <span>${progress.toStringAsFixed(1)}%</span>
              </div>
              <div class="progress-bar">
                <div class="progress-fill" style="width: ${progress}%"></div>
              </div>
            </div>
          ''';
    }).join('')}
      </div>
    ''';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: ExpansionTile(
        title: const Text(
          '📧 리포트 이메일로 받기',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        onExpansionChanged: (expanded) {
          setState(() => _isExpanded = expanded);
        },
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 40, // 버튼 높이와 동일하게 설정
                    child: TextField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        hintText: '이메일 주소 입력',
                        hintStyle: TextStyle(fontSize: 13),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                        border: OutlineInputBorder(),
                      ),
                      style: const TextStyle(fontSize: 13),
                      keyboardType: TextInputType.emailAddress,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 40,
                  child: ElevatedButton.icon(
                    onPressed: _isSending ? null : _sendEmail,
                    icon: _isSending
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send, size: 16),
                    label: Text(
                      _isSending ? '전송 중...' : '전송하기',
                      style: const TextStyle(fontSize: 13),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: TimeTrekTheme.vitaflowBrandColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
