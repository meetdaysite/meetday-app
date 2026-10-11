import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/network/api_client.dart';
import '../providers/events_provider.dart';

class CreateEventScreen extends ConsumerStatefulWidget {
  const CreateEventScreen({super.key, this.initialEvent});
  final Map<String, dynamic>? initialEvent;
  @override
  ConsumerState<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends ConsumerState<CreateEventScreen> {
  static const _labels = {
    'title': 'Event title', 'description': 'Description', 'eventType': 'Event type',
    'languages': 'Languages (comma separated)', 'tags': 'Tags (comma separated)',
    'venueName': 'Venue name', 'fullAddress': 'Full address', 'city': 'City',
    'whatToExpect': 'What to expect (one per line)', 'whoShouldAttend': 'Who should attend (one per line)',
    'ageRestriction': 'Age restriction', 'specialInstructions': 'Special instructions',
  };
  final Map<String, TextEditingController> _controllers = {};
  final _prompt = TextEditingController();
  final _latitude = TextEditingController();
  final _longitude = TextEditingController();
  final _refundHours = TextEditingController(text: '24');
  final _refundPercent = TextEditingController(text: '80');
  bool _changeVenue = false;
  String _refundTo = 'ORIGINAL_PAYMENT';
  final List<Map<String, dynamic>> _tickets = [];
  final List<Map<String, dynamic>> _media = [];
  List<Map<String, dynamic>> _categories = [];
  String? _categoryId;
  DateTime? _startDate;
  DateTime? _endDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  String _visibility = 'PUBLIC';
  String _refundType = 'NO_REFUND';
  bool _free = true;
  bool _busy = false;
  String? _savedId;
  String? _error;
  bool get _published => (widget.initialEvent?['status'] ?? '') == 'PUBLISHED';

  @override
  void initState() {
    super.initState();
    final live = widget.initialEvent ?? const <String, dynamic>{};
    final pending = live['pendingRevision'] is Map ? live['pendingRevision'] as Map : const {};
    final initial = <String, dynamic>{...live, ...Map<String, dynamic>.from(pending)};
    for (final key in _labels.keys) {
      final value = initial[key];
      _controllers[key] = TextEditingController(text: value is List
          ? value.join(key == 'languages' || key == 'tags' ? ', ' : '\n') : value?.toString() ?? '');
    }
    _categoryId = initial['categoryId']?.toString();
    _latitude.text = initial['latitude']?.toString() ?? '';
    _longitude.text = initial['longitude']?.toString() ?? '';
    _savedId = live['id']?.toString();
    _startDate = DateTime.tryParse((initial['eventDate'] ?? '').toString());
    _endDate = DateTime.tryParse((initial['endDate'] ?? '').toString());
    _startTime = _parseTime(initial['startTime']?.toString());
    _endTime = _parseTime(initial['endTime']?.toString());
    _free = initial['isFree'] != false;
    _visibility = (initial['visibility'] ?? 'PUBLIC').toString();
    if (initial['refundPolicy'] is Map) {
      final policy = initial['refundPolicy'] as Map;
      _refundType = policy['type']?.toString() ?? 'NO_REFUND';
      _refundTo = policy['refundTo']?.toString() ?? 'ORIGINAL_PAYMENT';
      _refundHours.text = policy['cutoffHours']?.toString() ?? '24';
      _refundPercent.text = policy['refundPercent']?.toString() ?? '80';
    }
    _tickets.addAll((initial['tickets'] as List? ?? const []).whereType<Map>().map((ticket) => {
      'name': ticket['name'] ?? '', 'price': ticket['price'] ?? 0,
      'totalCapacity': ticket['totalCapacity'] ?? 1, 'maxPerPerson': ticket['maxPerPerson'] ?? 1,
      'isFree': ticket['isFree'] == true,
    }));
    _media.addAll((initial['media'] as List? ?? const []).whereType<Map>().map((item) => {
      'key': item['key'], 'type': item['type'], 'order': item['order'] ?? 0,
    }));
    _loadCategories();
  }

  TimeOfDay? _parseTime(String? value) {
    if (value == null) return null;
    final match = RegExp(r'^(\d{1,2}):(\d{2})\s*(AM|PM)?$', caseSensitive: false).firstMatch(value.trim());
    if (match == null) return null;
    int hour = int.parse(match[1]!);
    final minute = int.parse(match[2]!);
    if (match[3] != null) hour = hour % 12 + (match[3]!.toUpperCase() == 'PM' ? 12 : 0);
    return hour < 24 && minute < 60 ? TimeOfDay(hour: hour, minute: minute) : null;
  }

  Future<void> _loadCategories() async {
    try {
      final response = await ref.read(apiClientProvider).getRequest('/categories');
      if (mounted) setState(() { _categories = (response as List).whereType<Map>().map(Map<String, dynamic>.from).toList(); });
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load categories.');
    }
  }

  List<String> _values(String key) => _controllers[key]!.text.split(
    key == 'languages' || key == 'tags' ? ',' : '\n').map((value) => value.trim()).where((value) => value.isNotEmpty).toList();

  Future<void> _save(bool submit) async {
    if (_busy) return;
    setState(() { _busy = true; _error = null; });
    try {
      final api = ref.read(apiClientProvider);
      final payload = <String, dynamic>{
        for (final key in _labels.keys)
          if (_published ? key != 'ageRestriction' : true)
            key: ['languages', 'tags', 'whatToExpect', 'whoShouldAttend'].contains(key)
                ? _values(key) : _controllers[key]!.text.trim(),
        if (_categoryId != null) 'categoryId': _categoryId,
        'media': _media,
      };
      if (_published) {
        if (_changeVenue) {
          final latitude = double.tryParse(_latitude.text);
          final longitude = double.tryParse(_longitude.text);
          if (latitude == null || longitude == null || latitude.abs() > 90 || longitude.abs() > 180) {
            throw const FormatException('Enter valid venue latitude and longitude.');
          }
          payload.addAll({'latitude': latitude, 'longitude': longitude});
        } else {
          payload.remove('venueName'); payload.remove('fullAddress'); payload.remove('city');
        }
        await api.dio.patch<dynamic>('/events/$_savedId/revision', data: payload);
      } else {
        payload.addAll({
          if (_startDate != null) 'eventDate': DateFormat('yyyy-MM-dd').format(_startDate!),
          if (_endDate != null) 'endDate': DateFormat('yyyy-MM-dd').format(_endDate!),
          if (_startTime != null) 'startTime': '${_startTime!.hour.toString().padLeft(2, '0')}:${_startTime!.minute.toString().padLeft(2, '0')}',
          if (_endTime != null) 'endTime': '${_endTime!.hour.toString().padLeft(2, '0')}:${_endTime!.minute.toString().padLeft(2, '0')}',
          'visibility': _visibility, 'isFree': _free,
          'tickets': _tickets.map((ticket) => {...ticket,
            'price': _free ? 0 : num.parse(ticket['price'].toString()),
            'totalCapacity': int.parse(ticket['totalCapacity'].toString()),
            'maxPerPerson': int.parse(ticket['maxPerPerson'].toString()), 'isFree': _free}).toList(),
          'refundPolicy': {'type': _refundType, 'refundTo': _refundTo,
            if (_refundType == 'PARTIAL') ...{
              'cutoffHours': int.parse(_refundHours.text),
              'refundPercent': int.parse(_refundPercent.text),
            }},
        });
        if (_savedId == null) {
          final response = await api.postRequest('/events', payload);
          _savedId = (response as Map)['id']?.toString();
          if (_savedId == null) throw const FormatException('Event ID was missing.');
        } else {
          await api.dio.patch<dynamic>('/events/$_savedId', data: payload);
        }
        if (submit) await api.dio.patch<dynamic>('/events/$_savedId/submit');
      }
      ref.invalidate(communityOwnedEventsProvider);
      if (_savedId != null) ref.invalidate(communityOwnedEventProvider(_savedId!));
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) setState(() => _error = error is DioException
          ? (error.response?.data is Map ? error.response!.data['message'] : error.message).toString()
          : error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickMedia(String type) async {
    final files = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp']);
    if (files.isEmpty || !mounted) return;
    setState(() => _busy = true);
    try {
      final file = files.first;
      final size = await file.length();
      if (size == null || size > 10 * 1024 * 1024) throw const FormatException('Image must be under 10 MB.');
      final contentType = file.extension == 'png' ? 'image/png' : file.extension == 'webp' ? 'image/webp' : 'image/jpeg';
      final response = await ref.read(apiClientProvider).postRequest('/storage/upload-url', {
        'context': 'EVENT_MEDIA', 'mediaType': type, 'contentType': contentType,
        if (_savedId != null) 'resourceId': _savedId,
      });
      final data = response as Map;
      await Dio().put<dynamic>((data['uploadUrl'] ?? data['url']).toString(), data: await file.readAsBytes(),
        options: Options(headers: {'Content-Type': contentType}));
      if (mounted) setState(() {
        if (type == 'COVER') _media.removeWhere((item) => item['type'] == 'COVER');
        _media.add({'key': data['key'], 'type': type, 'order': _media.length});
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not upload image. Please retry.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _generate() async {
    setState(() => _busy = true);
    try {
      final draft = await ref.read(apiClientProvider).postRequest('/events/copilot/generate-draft', {'prompt': _prompt.text.trim()});
      if (draft is! Map) throw const FormatException('Invalid AI draft.');
      if (mounted) setState(() {
        for (final key in _labels.keys) {
          final value = draft[key];
          if (value != null) _controllers[key]!.text = value is List ? value.join(key == 'languages' || key == 'tags' ? ', ' : '\n') : value.toString();
        }
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not generate event draft.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickDate(bool end) async {
    final now = DateTime.now();
    final date = await showDatePicker(context: context, initialDate: end ? _endDate ?? _startDate ?? now : _startDate ?? now,
      firstDate: now.subtract(const Duration(days: 365)), lastDate: now.add(const Duration(days: 730)));
    if (date != null && mounted) setState(() { if (end) _endDate = date; else _startDate = date; });
  }

  Future<void> _pickTime(bool end) async {
    final time = await showTimePicker(context: context, initialTime: end ? _endTime ?? TimeOfDay.now() : _startTime ?? TimeOfDay.now());
    if (time != null && mounted) setState(() { if (end) _endTime = time; else _startTime = time; });
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) { controller.dispose(); }
    _prompt.dispose(); super.dispose();
    _latitude.dispose(); _longitude.dispose(); _refundHours.dispose(); _refundPercent.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text(_published ? 'Edit event content' : 'Event draft')),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      if (_error != null) ListTile(title: Text(_error!), trailing: IconButton(tooltip: 'Retry categories',
        icon: const Icon(Icons.refresh_rounded), onPressed: _loadCategories)),
      TextField(controller: _prompt, maxLines: 3, maxLength: 2000, decoration: const InputDecoration(labelText: 'AI event brief')),
      OutlinedButton.icon(onPressed: _busy ? null : _generate, icon: const Icon(Icons.auto_awesome_rounded), label: const Text('Generate draft')),
      DropdownMenu<String>(initialSelection: _categories.any((category) => category['id'] == _categoryId) ? _categoryId : null,
        expandedInsets: EdgeInsets.zero, label: const Text('Category'), enableFilter: true,
        dropdownMenuEntries: _categories.map((category) => DropdownMenuEntry(value: category['id'].toString(), label: category['name'].toString())).toList(),
        onSelected: (id) => _categoryId = id),
      for (final entry in _labels.entries) Padding(padding: const EdgeInsets.only(top: 12), child: TextField(
        controller: _controllers[entry.key], enabled: !_busy && (!_published ||
          entry.key != 'ageRestriction' && (_changeVenue || !['venueName', 'fullAddress', 'city'].contains(entry.key))),
        maxLines: ['description', 'whatToExpect', 'whoShouldAttend'].contains(entry.key) ? 4 : 1,
        decoration: InputDecoration(labelText: entry.value))),
      if (_published) ...[
        SwitchListTile(title: const Text('Propose venue change'), value: _changeVenue,
          onChanged: _busy ? null : (value) => setState(() => _changeVenue = value)),
        if (_changeVenue) ...[
          TextField(controller: _latitude, keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
            decoration: const InputDecoration(labelText: 'Latitude')),
          TextField(controller: _longitude, keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
            decoration: const InputDecoration(labelText: 'Longitude')),
        ],
      ],
      if (!_published) ...[
        ListTile(title: Text('Start: ${_startDate == null ? 'Select date' : DateFormat('yyyy-MM-dd').format(_startDate!)}'), onTap: _busy ? null : () => _pickDate(false)),
        ListTile(title: Text('End: ${_endDate == null ? 'Select date' : DateFormat('yyyy-MM-dd').format(_endDate!)}'), onTap: _busy ? null : () => _pickDate(true)),
        ListTile(title: Text('Start time: ${_startTime?.format(context) ?? 'Select time'}'), onTap: _busy ? null : () => _pickTime(false)),
        ListTile(title: Text('End time: ${_endTime?.format(context) ?? 'Select time'}'), onTap: _busy ? null : () => _pickTime(true)),
        DropdownMenu<String>(initialSelection: _visibility, label: const Text('Visibility'), dropdownMenuEntries:
          ['PUBLIC', 'PRIVATE'].map((value) => DropdownMenuEntry(value: value, label: value)).toList(), onSelected: (value) => _visibility = value ?? 'PUBLIC'),
        SwitchListTile(title: const Text('Free event'), value: _free, onChanged: _busy ? null : (value) => setState(() => _free = value)),
        for (final ticket in _tickets) Column(key: ObjectKey(ticket), children: [
          for (final entry in const {'name': 'Ticket name', 'price': 'Price', 'totalCapacity': 'Capacity', 'maxPerPerson': 'Max per person'}.entries)
            TextFormField(initialValue: ticket[entry.key].toString(), enabled: !_busy && (!_free || entry.key != 'price'),
              decoration: InputDecoration(labelText: entry.value), keyboardType: entry.key == 'name' ? TextInputType.text : TextInputType.number,
              onChanged: (value) => ticket[entry.key] = value),
          IconButton(tooltip: 'Remove ticket', icon: const Icon(Icons.delete_outline_rounded), onPressed: _busy ? null : () => setState(() => _tickets.remove(ticket))),
        ]),
        OutlinedButton.icon(onPressed: _busy ? null : () => setState(() => _tickets.add({'name': '', 'price': 0, 'totalCapacity': 1, 'maxPerPerson': 1, 'isFree': _free})),
          icon: const Icon(Icons.add_rounded), label: const Text('Add ticket tier')),
        DropdownMenu<String>(initialSelection: _refundType, label: const Text('Refund policy'),
          dropdownMenuEntries: ['FULL', 'PARTIAL', 'NO_REFUND'].map((value) => DropdownMenuEntry(value: value, label: value)).toList(),
          onSelected: (value) => setState(() => _refundType = value ?? 'NO_REFUND')),
        if (_refundType == 'PARTIAL') ...[
          TextField(controller: _refundHours, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Refund cutoff hours')),
          TextField(controller: _refundPercent, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Refund percentage (1-99)')),
        ],
        DropdownMenu<String>(initialSelection: _refundTo, label: const Text('Refund destination'),
          dropdownMenuEntries: ['ORIGINAL_PAYMENT', 'PLATFORM_CREDIT'].map((value) => DropdownMenuEntry(value: value, label: value)).toList(),
          onSelected: (value) => _refundTo = value ?? 'ORIGINAL_PAYMENT'),
      ],
      OutlinedButton.icon(onPressed: _busy ? null : () => _pickMedia('COVER'), icon: const Icon(Icons.image_outlined), label: const Text('Choose cover')),
      OutlinedButton.icon(onPressed: _busy ? null : () => _pickMedia('GALLERY'), icon: const Icon(Icons.add_photo_alternate_outlined), label: const Text('Add gallery image')),
      for (final item in _media) ListTile(title: Text('${item['type']}: ${item['key'].toString().split('/').last}'), trailing: IconButton(
        tooltip: 'Remove media', icon: const Icon(Icons.close_rounded), onPressed: _busy ? null : () => setState(() => _media.remove(item)))),
      const SizedBox(height: 16),
      ElevatedButton.icon(onPressed: _busy ? null : () => _save(false), icon: const Icon(Icons.save_outlined),
        label: Text(_published ? 'Submit content revision' : 'Save draft')),
      if (!_published) OutlinedButton.icon(onPressed: _busy ? null : () => _save(true), icon: const Icon(Icons.send_rounded), label: const Text('Submit for review')),
      if (_busy) const LinearProgressIndicator(),
    ]));
}