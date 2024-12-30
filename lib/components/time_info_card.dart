import 'package:flutter/material.dart';

class TimeInfoCard extends StatefulWidget {
  final String timegroup;
  final double totalMonthlyTime;
  final double remainingTime;
  final double createdActionTime;
  final double totalActionTime;
  final Color groupColor;

  const TimeInfoCard({
    required this.timegroup,
    required this.totalMonthlyTime,
    required this.remainingTime,
    required this.createdActionTime,
    required this.totalActionTime,
    required this.groupColor,
  });

  @override
  State<TimeInfoCard> createState() => _TimeInfoCardState();
}

// ... _TimeInfoCardState 클래스의 전체 내용 ... 
class _TimeInfoCardState extends State<TimeInfoCard> {
  // 캐시된 툴팁 콘텐츠
  late final Widget _tooltipContent;

  @override
  void initState() {
    super.initState();
    // 초기화 시 한 번만 툴팁 콘텐츠를 생성
    _tooltipContent = _buildTooltipContent(
        widget.createdActionTime > widget.remainingTime,
        widget.remainingTime > 0
            ? ((widget.createdActionTime - widget.remainingTime) /
                widget.remainingTime *
                100)
            : 0.0);
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<void>(
      tooltip: '',
      offset: Offset(0, 20),
      position: PopupMenuPosition.under,
      itemBuilder: (context) => [
        PopupMenuItem(
          enabled: false,
          value: null,
          child: _tooltipContent,
        ),
      ],
      child: Card(
        margin: EdgeInsets.symmetric(horizontal: 4),
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Container(
          decoration: BoxDecoration(
            border: widget.createdActionTime > widget.remainingTime
                ? Border.all(
                    color: Colors.red,
                    width: 2,
                  )
                : null,
          ),
          padding: EdgeInsets.all(8),
          width: 160,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: AlwaysScrollableScrollPhysics(), // 웹과 모바일 모두 지원
              child: Container(
                width: 160,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 3,
                          height: 16, // 높이 증가
                          decoration: BoxDecoration(
                            color: widget.groupColor,
                            borderRadius: BorderRadius.circular(1.5),
                          ),
                        ),
                        SizedBox(width: 6),
                        Text(
                          widget.timegroup,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13, // 글자 크기 증가
                          ),
                        ),
                      ],
                    ),
                    if (widget.createdActionTime > widget.remainingTime) ...[
                      SizedBox(height: 4),
                      Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '⚠️ ${((widget.createdActionTime - widget.remainingTime) / widget.remainingTime * 100).toStringAsFixed(0)}% 초과',
                          style: TextStyle(
                            fontSize: 12, // 글자 크기 증가
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                    SizedBox(height: 8),
                    _buildTimeRow(
                      widget.createdActionTime,
                      widget.remainingTime,
                      widget.createdActionTime > widget.remainingTime
                          ? Colors.red
                          : Colors.orange,
                    ),
                    SizedBox(height: 4),
                    _buildTimeRow(
                      widget.totalActionTime,
                      widget.totalMonthlyTime,
                      Colors.green,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTooltipContent(
      bool isOverAllocated, double overAllocationPercentage) {
    // 잔여 시간 재계산
    final remainingTime = widget.remainingTime;
    final createdTime = widget.createdActionTime;
    final totalMonthly = widget.totalMonthlyTime;
    final totalAction = widget.totalActionTime;

    // 잔여 시간을 총 월할당 시간에서 생성된 액션 시간을 뺀 값으로 계산
    final adjustedRemainingTime = totalMonthly - createdTime;

    return Container(
      width: 240,
      padding: EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 헤더
          Row(
            children: [
              Icon(Icons.stars, color: widget.groupColor, size: 18),
              SizedBox(width: 8),
              Text(
                '${widget.timegroup} 요약',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          Divider(height: 16),

          // 시간 분석 섹션 업데이트 - remainingTime 대신 adjustedRemainingTime 사용
          Row(
            children: [
              Icon(Icons.analytics, color: Colors.blue, size: 16),
              SizedBox(width: 8),
              Text(
                '시간 분석',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          _buildTimeInfoRow('생성', createdTime, Icons.add_circle_outline),
          _buildTimeInfoRow(
              '잔여', adjustedRemainingTime, Icons.timer_outlined), // 수정된 부분
          _buildTimeInfoRow('총액션', totalAction, Icons.check_circle_outline),
          _buildTimeInfoRow('월할당', totalMonthly, Icons.calendar_today),

          // 경고 섹션 업데이트 (잔여 시간 기준)
          if (createdTime > remainingTime && remainingTime > 0) ...[
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ), // decoration 닫기
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning_amber, color: Colors.red, size: 16),
                      SizedBox(width: 8),
                      Text(
                        '시간 초과 경고',
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Text(
                    '• 잔여 시간 대비 ${((createdTime - remainingTime) / remainingTime * 100).toStringAsFixed(0)}% 초과',
                    style: TextStyle(color: Colors.red, fontSize: 12),
                  ),
                  Text(
                    '• 조정 필요: ${(createdTime - remainingTime).toStringAsFixed(1)}H',
                    style: TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],

          // 설명 섹션
          SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.grey[600], size: 16),
              SizedBox(width: 8),
              Text(
                '설명',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          _buildDescriptionRow('생성', '현재 등록된 액션 시간'),
          _buildDescriptionRow('잔여', '이번 달 남은 용 시간'),
          _buildDescriptionRow('총액션', '전체 액션 실행 시간'),
          _buildDescriptionRow('월할당', '이번 달 총 할당 시간'),
        ],
      ),
    );
  }

  Widget _buildTimeInfoRow(String label, double value, IconData icon) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.grey[600]),
          SizedBox(width: 8),
          Text(
            '$label:',
            style: TextStyle(fontSize: 12),
          ),
          SizedBox(width: 4),
          Text(
            '${value.toStringAsFixed(1)}H',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionRow(String term, String description) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$term: ',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          Expanded(
            child: Text(
              description,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeRow(double value, double total, Color color) {
    final percentage = total > 0 ? (value / total * 100) : 0.0;
    final isStable = percentage <= 100;

    return Container(
      width: 160,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              '${value.toStringAsFixed(1)}/${total.toStringAsFixed(1)}H',
              style: TextStyle(
                fontSize: 12, // 글자 크기 증가
                color: Colors.grey[700],
                fontWeight: FontWeight.w500, // 약간의 굵기 추가
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: color.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${percentage.toStringAsFixed(0)}%',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 12, // 글자 크기 증가
                    fontWeight: FontWeight.bold,
                    color: color,
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