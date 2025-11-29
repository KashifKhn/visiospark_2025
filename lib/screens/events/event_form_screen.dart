import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/event_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/event_service.dart';
import '../../theme/app_colors.dart';

class EventFormScreen extends StatefulWidget {
  final String? eventId; // null = create, non-null = edit

  const EventFormScreen({super.key, this.eventId});

  @override
  State<EventFormScreen> createState() => _EventFormScreenState();
}

class _EventFormScreenState extends State<EventFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final EventService _eventService = EventService();

  // Controllers
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _venueController = TextEditingController();
  final _capacityController = TextEditingController();
  final _imageUrlController = TextEditingController();
  final _tagsController = TextEditingController();

  // Form values
  String _eventType = 'technical';
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  DateTime? _selectedEndDate;
  TimeOfDay? _selectedEndTime;
  DateTime? _registrationDeadline;

  bool _isLoading = false;
  EventModel? _existingEvent;

  @override
  void initState() {
    super.initState();
    if (widget.eventId != null) {
      _loadEvent();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _venueController.dispose();
    _capacityController.dispose();
    _imageUrlController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _loadEvent() async {
    setState(() => _isLoading = true);
    try {
      final event = await _eventService.getEventById(widget.eventId!);
      if (event != null) {
        setState(() {
          _existingEvent = event;
          _titleController.text = event.title;
          _descriptionController.text = event.description ?? '';
          _venueController.text = event.venue;
          _capacityController.text = event.capacity.toString();
          _imageUrlController.text = event.imageUrl ?? '';
          _tagsController.text = event.tags?.join(', ') ?? '';
          _eventType = event.eventType;
          _selectedDate = event.dateTime;
          _selectedTime = TimeOfDay.fromDateTime(event.dateTime);
          if (event.endTime != null) {
            _selectedEndDate = event.endTime;
            _selectedEndTime = TimeOfDay.fromDateTime(event.endTime!);
          }
          _registrationDeadline = event.registrationDeadline;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading event: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDate(BuildContext context, {bool isEndDate = false}) async {
    final now = DateTime.now();
    final initialDate = isEndDate
        ? (_selectedEndDate ?? _selectedDate ?? now)
        : (_selectedDate ?? now);

    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: now,
      lastDate: DateTime(now.year + 2),
    );

    if (date != null) {
      setState(() {
        if (isEndDate) {
          _selectedEndDate = date;
        } else {
          _selectedDate = date;
        }
      });
    }
  }

  Future<void> _selectTime(BuildContext context, {bool isEndTime = false}) async {
    final initialTime = isEndTime
        ? (_selectedEndTime ?? TimeOfDay.now())
        : (_selectedTime ?? TimeOfDay.now());

    final time = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );

    if (time != null) {
      setState(() {
        if (isEndTime) {
          _selectedEndTime = time;
        } else {
          _selectedTime = time;
        }
      });
    }
  }

  Future<void> _selectRegistrationDeadline(BuildContext context) async {
    final now = DateTime.now();
    final maxDate = _selectedDate ?? DateTime(now.year + 2);

    final date = await showDatePicker(
      context: context,
      initialDate: _registrationDeadline ?? now,
      firstDate: now,
      lastDate: maxDate,
    );

    if (date != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_registrationDeadline ?? now),
      );

      if (time != null && mounted) {
        setState(() {
          _registrationDeadline = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  DateTime _combineDateTime(DateTime date, TimeOfDay time) {
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _saveEvent() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select event date and time')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authProvider = context.read<AuthProvider>();
      final user = authProvider.user;

      if (user == null || user.societyId == null) {
        throw Exception('Society information not found');
      }

      final dateTime = _combineDateTime(_selectedDate!, _selectedTime!);
      DateTime? endTime;
      if (_selectedEndDate != null && _selectedEndTime != null) {
        endTime = _combineDateTime(_selectedEndDate!, _selectedEndTime!);
      }

      // Parse tags
      final tags = _tagsController.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      if (widget.eventId != null) {
        // Update existing event
        await _eventService.updateEvent(
          widget.eventId!,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          eventType: _eventType,
          startTime: dateTime,
          endTime: endTime,
          location: _venueController.text.trim(),
          maxParticipants: int.parse(_capacityController.text),
          imageUrl: _imageUrlController.text.trim().isEmpty
              ? null
              : _imageUrlController.text.trim(),
          tags: tags.isEmpty ? null : tags,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Event updated successfully')),
          );
          Navigator.pop(context, true);
        }
      } else {
        // Create new event
        await _eventService.createEvent(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          societyId: user.societyId!,
          startTime: dateTime,
          endTime: endTime ?? dateTime.add(const Duration(hours: 2)),
          location: _venueController.text.trim(),
          eventType: _eventType,
          maxParticipants: int.parse(_capacityController.text),
          imageUrl: _imageUrlController.text.trim().isEmpty
              ? null
              : _imageUrlController.text.trim(),
          tags: tags.isEmpty ? null : tags,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Event created successfully')),
          );
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving event: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.eventId != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Event' : 'Create Event'),
        actions: [
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _saveEvent,
              child: Text(
                isEdit ? 'UPDATE' : 'CREATE',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
      body: _isLoading && isEdit
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Title
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Event Title *',
                      hintText: 'e.g., AI Workshop',
                      prefixIcon: Icon(Icons.title),
                    ),
                    textCapitalization: TextCapitalization.words,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter event title';
                      }
                      if (value.trim().length < 3) {
                        return 'Title must be at least 3 characters';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  // Description
                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      hintText: 'Enter event details...',
                      prefixIcon: Icon(Icons.description),
                    ),
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                  ),

                  const SizedBox(height: 16),

                  // Event Type
                  DropdownButtonFormField<String>(
                    value: _eventType,
                    decoration: const InputDecoration(
                      labelText: 'Event Type *',
                      prefixIcon: Icon(Icons.category),
                    ),
                    items: ['technical', 'literary', 'sports']
                        .map((type) => DropdownMenuItem(
                              value: type,
                              child: Text(type[0].toUpperCase() + type.substring(1)),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() => _eventType = value!);
                    },
                  ),

                  const SizedBox(height: 16),

                  // Date and Time
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => _selectDate(context),
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Event Date *',
                              prefixIcon: Icon(Icons.calendar_today),
                            ),
                            child: Text(
                              _selectedDate != null
                                  ? DateFormat('MMM dd, yyyy').format(_selectedDate!)
                                  : 'Select date',
                              style: TextStyle(
                                color: _selectedDate != null
                                    ? null
                                    : AppColors.gray400,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: InkWell(
                          onTap: () => _selectTime(context),
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Start Time *',
                              prefixIcon: Icon(Icons.access_time),
                            ),
                            child: Text(
                              _selectedTime != null
                                  ? _selectedTime!.format(context)
                                  : 'Select time',
                              style: TextStyle(
                                color: _selectedTime != null
                                    ? null
                                    : AppColors.gray400,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // End Date and Time (Optional)
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => _selectDate(context, isEndDate: true),
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'End Date (Optional)',
                              prefixIcon: Icon(Icons.calendar_today),
                            ),
                            child: Text(
                              _selectedEndDate != null
                                  ? DateFormat('MMM dd, yyyy').format(_selectedEndDate!)
                                  : 'Select end date',
                              style: TextStyle(
                                color: _selectedEndDate != null
                                    ? null
                                    : AppColors.gray400,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: InkWell(
                          onTap: () => _selectTime(context, isEndTime: true),
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'End Time (Optional)',
                              prefixIcon: Icon(Icons.access_time),
                            ),
                            child: Text(
                              _selectedEndTime != null
                                  ? _selectedEndTime!.format(context)
                                  : 'Select end time',
                              style: TextStyle(
                                color: _selectedEndTime != null
                                    ? null
                                    : AppColors.gray400,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Venue
                  TextFormField(
                    controller: _venueController,
                    decoration: const InputDecoration(
                      labelText: 'Venue *',
                      hintText: 'e.g., Main Auditorium',
                      prefixIcon: Icon(Icons.location_on),
                    ),
                    textCapitalization: TextCapitalization.words,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter venue';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  // Capacity
                  TextFormField(
                    controller: _capacityController,
                    decoration: const InputDecoration(
                      labelText: 'Capacity *',
                      hintText: 'Maximum participants',
                      prefixIcon: Icon(Icons.people),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter capacity';
                      }
                      final capacity = int.tryParse(value);
                      if (capacity == null || capacity < 1) {
                        return 'Capacity must be at least 1';
                      }
                      if (isEdit && _existingEvent != null) {
                        if (capacity < _existingEvent!.registeredCount) {
                          return 'Cannot reduce below ${_existingEvent!.registeredCount} (current registrations)';
                        }
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  // Registration Deadline
                  InkWell(
                    onTap: () => _selectRegistrationDeadline(context),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Registration Deadline (Optional)',
                        prefixIcon: const Icon(Icons.event_available),
                        suffixIcon: _registrationDeadline != null
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  setState(() => _registrationDeadline = null);
                                },
                              )
                            : null,
                      ),
                      child: Text(
                        _registrationDeadline != null
                            ? DateFormat('MMM dd, yyyy • hh:mm a')
                                .format(_registrationDeadline!)
                            : 'No deadline',
                        style: TextStyle(
                          color: _registrationDeadline != null
                              ? null
                              : AppColors.gray400,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Image URL
                  TextFormField(
                    controller: _imageUrlController,
                    decoration: const InputDecoration(
                      labelText: 'Image URL (Optional)',
                      hintText: 'https://example.com/image.jpg',
                      prefixIcon: Icon(Icons.image),
                    ),
                    keyboardType: TextInputType.url,
                  ),

                  const SizedBox(height: 16),

                  // Tags
                  TextFormField(
                    controller: _tagsController,
                    decoration: const InputDecoration(
                      labelText: 'Tags (Optional)',
                      hintText: 'AI, Workshop, Beginners (comma-separated)',
                      prefixIcon: Icon(Icons.label),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Info card
                  Card(
                    color: AppColors.infoLight,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Icon(Icons.info, color: AppColors.info),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Events will be automatically assigned to your society. Students can register and receive updates.',
                              style: TextStyle(
                                color: AppColors.info,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }
}
