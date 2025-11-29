import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/event_service.dart';
import '../../services/registration_service.dart';
import '../../services/feedback_service.dart';
import '../../models/event_model.dart';
import '../../models/feedback_model.dart';
import '../../theme/app_colors.dart';
import '../../core/constants/constants.dart';
import '../../core/utils/logger.dart';

class EventDetailScreen extends StatefulWidget {
  final String eventId;

  const EventDetailScreen({super.key, required this.eventId});

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  final EventService _eventService = EventService();
  final RegistrationService _registrationService = RegistrationService();
  final FeedbackService _feedbackService = FeedbackService();

  EventModel? _event;
  bool _isLoading = true;
  bool _isRegistered = false;
  bool _isRegistering = false;
  double _averageRating = 0.0;
  List<FeedbackModel> _feedbacks = [];

  @override
  void initState() {
    super.initState();
    _loadEventDetails();
  }

  Future<void> _loadEventDetails() async {
    setState(() => _isLoading = true);

    try {
      final authProvider = context.read<AuthProvider>();
      final userId = authProvider.user?.id;

      final event = await _eventService.getEventById(widget.eventId);
      
      if (event == null) {
        throw Exception('Event not found');
      }

      final isRegistered = userId != null
          ? await _registrationService.isUserRegistered(widget.eventId, userId)
          : false;

      final rating = await _feedbackService.getEventAverageRating(widget.eventId);
      final feedbacks = await _feedbackService.getEventFeedback(widget.eventId);

      setState(() {
        _event = event;
        _isRegistered = isRegistered;
        _averageRating = rating;
        _feedbacks = feedbacks.take(5).toList();
        _isLoading = false;
      });
    } catch (e) {
      AppLogger.error('Error loading event details', e);
      setState(() => _isLoading = false);
    }
  }

  Future<void> _registerForEvent() async {
    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.user?.id;

    if (userId == null) {
      _showSnackBar('Please login to register', isError: true);
      return;
    }

    setState(() => _isRegistering = true);

    try {
      await _registrationService.registerForEvent(
        eventId: widget.eventId,
        userId: userId,
      );

      setState(() {
        _isRegistered = true;
        _isRegistering = false;
      });

      _showSnackBar('Successfully registered for event!');
      _loadEventDetails(); // Refresh to update registered count
    } catch (e) {
      setState(() => _isRegistering = false);
      AppLogger.error('Error registering for event', e);
      _showSnackBar(e.toString(), isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
      ),
    );
  }

  Color _getSocietyColor() {
    if (_event?.society?.shortName == null) return AppColors.primary;
    switch (_event!.society!.shortName) {
      case 'ACM':
        return AppColors.acmColor;
      case 'CLS':
        return AppColors.clsColor;
      case 'CSS':
        return AppColors.cssColor;
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _event == null
              ? _buildErrorState()
              : CustomScrollView(
                  slivers: [
                    _buildAppBar(),
                    SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildEventHeader(),
                          _buildEventInfo(),
                          _buildDescription(),
                          _buildLocationSection(),
                          _buildCapacitySection(),
                          if (_feedbacks.isNotEmpty) _buildFeedbackSection(),
                          const SizedBox(height: 100),
                        ],
                      ),
                    ),
                  ],
                ),
      bottomNavigationBar: _event != null ? _buildBottomBar() : null,
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: AppColors.error),
          const SizedBox(height: 16),
          const Text(
            'Event not found',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Go Back'),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    final societyColor = _getSocietyColor();

    return SliverAppBar(
      expandedHeight: 250,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (_event!.imageUrl != null)
              Image.network(
                _event!.imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [societyColor, societyColor.withValues(alpha: 0.7)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: const Icon(Icons.event, size: 80, color: Colors.white),
                  );
                },
              )
            else
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [societyColor, societyColor.withValues(alpha: 0.7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Icon(Icons.event, size: 80, color: Colors.white),
              ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.7),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.share),
          onPressed: () {
            // Share event functionality
          },
        ),
        IconButton(
          icon: const Icon(Icons.calendar_today),
          onPressed: () {
            // Add to calendar functionality
          },
        ),
      ],
    );
  }

  Widget _buildEventHeader() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getSocietyColor().withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _getSocietyColor().withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _getSocietyIcon(),
                      size: 16,
                      color: _getSocietyColor(),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _event!.society?.name ?? 'Unknown',
                      style: TextStyle(
                        color: _getSocietyColor(),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (_averageRating > 0) ...[
                const Icon(Icons.star, color: AppColors.warning, size: 20),
                const SizedBox(width: 4),
                Text(
                  _averageRating.toStringAsFixed(1),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _event!.title,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _getStatusColor().withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _event!.status.toUpperCase(),
              style: TextStyle(
                color: _getStatusColor(),
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getSocietyIcon() {
    switch (_event!.society?.shortName) {
      case 'ACM':
        return Icons.code;
      case 'CLS':
        return Icons.book;
      case 'CSS':
        return Icons.sports_soccer;
      default:
        return Icons.groups;
    }
  }

  Color _getStatusColor() {
    switch (_event!.status) {
      case 'upcoming':
        return AppColors.success;
      case 'ongoing':
        return AppColors.warning;
      case 'completed':
        return AppColors.info;
      case 'cancelled':
        return AppColors.error;
      default:
        return AppColors.gray500;
    }
  }

  Widget _buildEventInfo() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          _buildInfoRow(
            Icons.access_time,
            'Date & Time',
            _formatDateTime(_event!.dateTime),
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
            Icons.location_on,
            'Venue',
            _event!.venue,
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
            Icons.category,
            'Event Type',
            _formatEventType(_event!.eventType),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _getSocietyColor().withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: _getSocietyColor(), size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.gray500,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDescription() {
    if (_event!.description == null || _event!.description!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'About Event',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _event!.description!,
            style: const TextStyle(
              fontSize: 15,
              height: 1.6,
              color: AppColors.gray700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationSection() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Location',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.gray100,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _getSocietyColor().withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.location_on,
                    color: _getSocietyColor(),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Venue',
                        style: TextStyle(
                          color: AppColors.gray500,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _event!.venue,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.map),
                  onPressed: () {
                    // Open map
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCapacitySection() {
    final spotsLeft = _event!.capacity - _event!.registeredCount;
    final percentage = (_event!.registeredCount / _event!.capacity * 100).clamp(0, 100);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Capacity',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${_event!.registeredCount} / ${_event!.capacity}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.gray600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: percentage / 100,
              minHeight: 8,
              backgroundColor: AppColors.gray200,
              valueColor: AlwaysStoppedAnimation<Color>(_getSocietyColor()),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            spotsLeft > 0
                ? '$spotsLeft spots remaining'
                : 'Event is full',
            style: TextStyle(
              color: spotsLeft > 0 ? AppColors.gray600 : AppColors.error,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedbackSection() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Reviews',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    AppConstants.eventFeedbackRoute,
                    arguments: widget.eventId,
                  );
                },
                child: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _feedbacks.length,
            itemBuilder: (context, index) {
              return _buildFeedbackCard(_feedbacks[index]);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFeedbackCard(FeedbackModel feedback) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: _getSocietyColor().withValues(alpha: 0.2),
                  child: Text(
                    feedback.user?.fullName?.substring(0, 1).toUpperCase() ?? 'U',
                    style: TextStyle(
                      color: _getSocietyColor(),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        feedback.user?.fullName ?? 'Anonymous',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Row(
                        children: List.generate(5, (index) {
                          return Icon(
                            index < feedback.rating
                                ? Icons.star
                                : Icons.star_border,
                            size: 16,
                            color: AppColors.warning,
                          );
                        }),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (feedback.comment != null && feedback.comment!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                feedback.comment!,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.gray700,
                  height: 1.4,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    final authProvider = context.watch<AuthProvider>();
    final isHandler = authProvider.user?.role == AppConstants.roleSocietyHandler;

    if (isHandler) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pushNamed(
                      context,
                      AppConstants.editEventRoute,
                      arguments: widget.eventId,
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(color: _getSocietyColor()),
                  ),
                  child: const Text('Edit Event'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushNamed(
                      context,
                      AppConstants.eventRegistrationsRoute,
                      arguments: widget.eventId,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _getSocietyColor(),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('View Registrations'),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: _isRegistered
            ? ElevatedButton(
                onPressed: null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  disabledBackgroundColor: AppColors.success.withValues(alpha: 0.5),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      'Already Registered',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              )
            : ElevatedButton(
                onPressed: _event!.isFull || _isRegistering ? null : _registerForEvent,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _getSocietyColor(),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isRegistering
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        _event!.isFull ? 'Event Full' : 'Register Now',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    final dayName = days[dateTime.weekday - 1];
    final month = months[dateTime.month - 1];
    final day = dateTime.day;
    final year = dateTime.year;
    final time = _formatTime(dateTime);

    return '$dayName, $month $day, $year at $time';
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:$minute $period';
  }

  String _formatEventType(String type) {
    return type[0].toUpperCase() + type.substring(1);
  }
}
