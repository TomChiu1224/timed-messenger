import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'models/task_category.dart';
import 'models/scheduled_message.dart';
import 'services/theme_manager.dart';
import 'app_timezones.dart';
import 'firebase_service.dart';

class ScheduleFormWidget extends StatefulWidget {
  final ThemeManager themeManager;
  final Function(ScheduledMessage) onAdd;
  final List<TaskCategory> categories;
  final List<String> availableTags;

  const ScheduleFormWidget({
    super.key,
    required this.themeManager,
    required this.onAdd,
    required this.categories,
    required this.availableTags,
  });

  @override
  State<ScheduleFormWidget> createState() => _ScheduleFormWidgetState();
}

class _ScheduleFormWidgetState extends State<ScheduleFormWidget> {
  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  Future<void> _loadFriends() async {
    setState(() => _loadingFriends = true);
    try {
      final FirebaseService firebaseService = FirebaseService();
      final friends = await firebaseService.getFriendList();
      setState(() {
        _friendsList = friends;
        _loadingFriends = false;
      });
    } catch (e) {
      setState(() => _loadingFriends = false);
    }
  }

  void _resetForm() {
    _messageController.clear();
    _selectedDateTime = null;
    _repeatType = 'none';
    _selectedWeekdays.clear();
    _selectedMonths.clear();
    _selectedDates.clear();
    _customRepeatCount = 0;
    _monthlyOrdinal = 1;
    _monthlyWeekday = 1;
    _repeatInterval = 1;
    _repeatIntervalUnit = 'days';
    _startDate = null;
    _endDate = null;
    _selectedTimeZone = 'Asia/Taipei';
    _selectedTimeZoneName = '台灣時間 (GMT+8)';
    _soundEnabled = true;
    _selectedSoundId = 'notification';
    _soundVolume = 0.8;
    _soundRepeat = 1;
    _selectedCategoryId = null;
    _selectedTags.clear();
    _selectedReceiverId = null;
    _selectedReceiverName = null;
    setState(() {});
  }

  void _pickDateTime() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );
      if (pickedTime != null) {
        setState(() {
          _selectedDateTime = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
  }

  // ====== 狀態變數 ======
  final TextEditingController _messageController = TextEditingController();
  DateTime? _selectedDateTime;
  String _repeatType = 'none';
  final List<int> _selectedWeekdays = [];
  final List<int> _selectedMonths = [];
  final List<int> _selectedDates = [];
  int _customRepeatCount = 0;
  DateTime? _startDate;
  DateTime? _endDate;
  int _monthlyOrdinal = 1;
  int _monthlyWeekday = 1;
  int _repeatInterval = 1;
  String _repeatIntervalUnit = 'days';
  String _selectedTimeZone = 'Asia/Taipei';
  String _selectedTimeZoneName = '台灣時間 (GMT+8)';
  bool _soundEnabled = true;
  String _selectedSoundId = 'notification';
  double _soundVolume = 0.8;
  int _soundRepeat = 1;

  int? _selectedCategoryId;
  final List<String> _selectedTags = [];

  // ✅ 收件人相關
  String? _selectedReceiverId;
  String? _selectedReceiverName;
  List<Map<String, dynamic>> _friendsList = [];
  bool _loadingFriends = false;

  @override
  Widget build(BuildContext context) {
    // ========== 重複模式選擇 ==========
    const repeatTypes = [
      {'value': 'none', 'label': '不重複'},
      {'value': 'daily', 'label': '每日'},
      {'value': 'weekly', 'label': '每週'},
      {'value': 'weekdays', 'label': '平日 (週一至週五)'},
      {'value': 'monthly', 'label': '每月'},
      {'value': 'monthlyDates', 'label': '每月指定日期'},
      {'value': 'monthlyOrdinal', 'label': '每月第幾個星期幾'},
      {'value': 'yearly', 'label': '每年'},
      {'value': 'interval', 'label': '自訂間隔'},
      {'value': 'custom', 'label': '自訂次數'},
    ];

    Widget repeatTypeDropdown = DropdownButtonFormField<String>(
      value: _repeatType,
      decoration: const InputDecoration(
        labelText: '重複模式',
        border: OutlineInputBorder(),
      ),
      onChanged: (value) => setState(() => _repeatType = value!),
      items: repeatTypes
          .map((type) => DropdownMenuItem(
                value: type['value'],
                child: Text(type['label']!),
              ))
          .toList(),
    );

    // ========== 條件UI ==========
    List<Widget> repeatConditionWidgets = [];
    if (_repeatType == 'weekly') {
      repeatConditionWidgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 8),
          child: Wrap(
            spacing: 8,
            children: List.generate(7, (i) {
              const daysText = ['日', '一', '二', '三', '四', '五', '六'];
              return FilterChip(
                label: Text('週${daysText[i]}'),
                selected: _selectedWeekdays.contains(i),
                onSelected: (selected) {
                  setState(() {
                    selected
                        ? _selectedWeekdays.add(i)
                        : _selectedWeekdays.remove(i);
                  });
                },
              );
            }),
          ),
        ),
      );
    }
    if (_repeatType == 'monthlyDates' || _repeatType == 'monthly') {
      repeatConditionWidgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 8),
          child: Wrap(
            spacing: 4,
            runSpacing: 4,
            children: List.generate(31, (i) {
              final day = i + 1;
              return FilterChip(
                label: Text('$day'),
                selected: _selectedDates.contains(day),
                onSelected: (selected) {
                  setState(() {
                    selected
                        ? _selectedDates.add(day)
                        : _selectedDates.remove(day);
                  });
                },
              );
            }),
          ),
        ),
      );
    }
    if (_repeatType == 'monthlyOrdinal') {
      repeatConditionWidgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 8),
          child: Row(
            children: [
              const Text('每月第'),
              const SizedBox(width: 8),
              DropdownButton<int>(
                value: _monthlyOrdinal,
                onChanged: (value) {
                  if (value != null) setState(() => _monthlyOrdinal = value);
                },
                items: [1, 2, 3, 4, 5]
                    .map((v) => DropdownMenuItem(
                        value: v, child: Text(v == 5 ? '最後一' : '$v')))
                    .toList(),
              ),
              const SizedBox(width: 8),
              const Text('個'),
              const SizedBox(width: 8),
              DropdownButton<int>(
                value: _monthlyWeekday,
                onChanged: (value) {
                  if (value != null) setState(() => _monthlyWeekday = value);
                },
                items: [0, 1, 2, 3, 4, 5, 6]
                    .map((v) => DropdownMenuItem(
                        value: v, child: Text('星期${'日一二三四五六'[v]}')))
                    .toList(),
              ),
            ],
          ),
        ),
      );
    }
    if (_repeatType == 'interval') {
      repeatConditionWidgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 8),
          child: Row(
            children: [
              const Text('每'),
              const SizedBox(width: 8),
              SizedBox(
                width: 80,
                child: TextField(
                  decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    final parsed = int.tryParse(value);
                    if (parsed != null && parsed > 0)
                      setState(() => _repeatInterval = parsed);
                  },
                  controller:
                      TextEditingController(text: _repeatInterval.toString()),
                ),
              ),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _repeatIntervalUnit,
                onChanged: (value) {
                  if (value != null)
                    setState(() => _repeatIntervalUnit = value);
                },
                items: const [
                  DropdownMenuItem(value: 'days', child: Text('天')),
                  DropdownMenuItem(value: 'weeks', child: Text('週')),
                  DropdownMenuItem(value: 'months', child: Text('月')),
                ],
              ),
              const Text('重複一次'),
            ],
          ),
        ),
      );
    }
    if (_repeatType == 'custom') {
      repeatConditionWidgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 8),
          child: SizedBox(
            width: 120,
            child: TextField(
              decoration: const InputDecoration(
                  border: OutlineInputBorder(), labelText: '重複次數'),
              keyboardType: TextInputType.number,
              onChanged: (val) =>
                  setState(() => _customRepeatCount = int.tryParse(val) ?? 0),
              controller:
                  TextEditingController(text: _customRepeatCount.toString()),
            ),
          ),
        ),
      );
    }

    // ========== 收件人選擇 ==========
    Widget receiverSelector = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('選擇收件人（可選）',
            style: TextStyle(fontSize: 14, color: Colors.grey)),
        const SizedBox(height: 8),
        _loadingFriends
            ? const Center(child: CircularProgressIndicator())
            : _friendsList.isEmpty
                ? Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('還沒有好友，請先到好友頁面新增好友',
                        style: TextStyle(color: Colors.grey)),
                  )
                : DropdownButtonFormField<String>(
                    value: _selectedReceiverId,
                    decoration: const InputDecoration(
                      labelText: '收件人',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                    hint: const Text('選擇收件人（不選則為本地提醒）'),
                    onChanged: (value) {
                      setState(() {
                        _selectedReceiverId = value;
                        if (value == null) {
                          _selectedReceiverName = null;
                        } else {
                          final friend =
                              _friendsList.firstWhere((f) => f['uid'] == value);
                          _selectedReceiverName =
                              friend['displayName'] ?? friend['username'];
                        }
                      });
                    },
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('不指定（本地提醒）'),
                      ),
                      ..._friendsList.map((friend) => DropdownMenuItem<String>(
                            value: friend['uid'],
                            child: Text(
                                '${friend['displayName'] ?? '未知'} @${friend['username'] ?? ''}'),
                          )),
                    ],
                  ),
      ],
    );

    // ========== 送出按鈕與驗證 ==========
    Widget submitButton = SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        icon: const Icon(Icons.add),
        label: const Text('新增排程'),
        style: ElevatedButton.styleFrom(
          backgroundColor: widget.themeManager.currentColors['primary'],
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        onPressed: () {
          if (_messageController.text.trim().isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('請輸入任務內容'), backgroundColor: Colors.orange));
            return;
          }
          if (_selectedDateTime == null) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('請設定觸發提醒時間'), backgroundColor: Colors.orange));
            return;
          }
          final newMsg = ScheduledMessage(
            _messageController.text.trim(),
            _selectedDateTime!,
            repeatType: _repeatType,
            repeatDays: List.from(_selectedWeekdays),
            repeatCount: _customRepeatCount,
            currentCount: 0,
            repeatMonths: List.from(_selectedMonths),
            repeatDates: List.from(_selectedDates),
            repeatMonthlyOrdinal: _monthlyOrdinal,
            repeatMonthlyWeekday: _monthlyWeekday,
            repeatInterval: _repeatInterval,
            repeatIntervalUnit: _repeatIntervalUnit,
            startDate: _startDate,
            endDate: _endDate,
            targetTimeZone: _selectedTimeZone,
            targetTimeZoneName: _selectedTimeZoneName,
            soundEnabled: _soundEnabled,
            soundType: 'system',
            soundPath: _selectedSoundId,
            soundVolume: _soundVolume,
            soundRepeat: _soundRepeat,
            categoryId: _selectedCategoryId,
            tags: List.from(_selectedTags),
            receiverId: _selectedReceiverId,
            receiverName: _selectedReceiverName,
          );
          widget.onAdd(newMsg);
          _resetForm();
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('排程已新增！'), backgroundColor: Colors.green));
        },
      ),
    );

    // ========== 組合所有UI ==========
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('新增排程',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(
                controller: _messageController,
                decoration: const InputDecoration(
                  labelText: '請輸入訊息內容',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _pickDateTime,
                      icon: const Icon(Icons.schedule),
                      label: Text(_selectedDateTime == null
                          ? '選擇時間'
                          : DateFormat('yyyy-MM-dd HH:mm')
                              .format(_selectedDateTime!)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedTimeZone,
                decoration: const InputDecoration(
                  labelText: '選擇時區',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.public),
                ),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    final timeZoneInfo = AppTimeZones.getTimeZoneById(newValue);
                    if (timeZoneInfo != null) {
                      setState(() {
                        _selectedTimeZone = newValue;
                        _selectedTimeZoneName = timeZoneInfo.displayName;
                      });
                    }
                  }
                },
                items: AppTimeZones.supportedZones
                    .map<DropdownMenuItem<String>>((zone) {
                  return DropdownMenuItem<String>(
                    value: zone.id,
                    child: Text(zone.displayName),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                value: _selectedCategoryId,
                decoration: const InputDecoration(
                  labelText: '選擇分類（可選）',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category),
                ),
                onChanged: (int? newValue) {
                  setState(() {
                    _selectedCategoryId = newValue;
                  });
                },
                items: [
                  const DropdownMenuItem<int>(
                    value: null,
                    child: Text('無分類'),
                  ),
                  ...widget.categories.map<DropdownMenuItem<int>>((category) {
                    return DropdownMenuItem<int>(
                      value: category.id,
                      child: Row(
                        children: [
                          Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: category.color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(category.icon, size: 16),
                          const SizedBox(width: 8),
                          Text(category.name),
                        ],
                      ),
                    );
                  }),
                ],
              ),
              const SizedBox(height: 16),
              repeatTypeDropdown,
              ...repeatConditionWidgets,
              const SizedBox(height: 16),
              receiverSelector,
              const SizedBox(height: 16),
              submitButton,
            ],
          ),
        ),
      ),
    );
  }
}
