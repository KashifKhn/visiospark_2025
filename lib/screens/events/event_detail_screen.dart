import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:share_plus/share_plus.dart';
import '../../providers/auth_provider.dart';
import '../../services/event_service.dart';
import '../../services/registration_service.dart';
import '../../services/feedback_service.dart';
import '../../services/ai_service.dart';
import '../../core/config/supabase_config.dart';
import '../../models/event_model.dart';
import '../../models/feedback_model.dart';
import '../../models/event_question_model.dart';
import '../../models/ai_message_model.dart';
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
  final AIService _aiService = AIService();

  EventModel? _event;
  bool _isLoading = true;
  bool _isRegistered = false;
  bool _isRegistering = false;
  double _averageRating = 0.0;
  List<FeedbackModel> _feedbacks = [];
  List<EventQuestionModel> _questions = [];
  final TextEditingController _questionController = TextEditingController();
  final TextEditingController _aiQuestionController = TextEditingController();
  bool _isPostingQuestion = false;
  final List<AIMessageModel> _aiMessages = [];
  bool _isAIThinking = false;
  String? _expandedQuestionId;
  final Map<String, List<Map<String, dynamic>>> _questionAnswers = {};
  final Map<String, TextEditingController> _answerControllers = {};
  StateSetter? _modalStateSetter;

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
      
      // Load Q&A
      final questions = await _loadQuestions();

      setState(() {
        _event = event;
        _isRegistered = isRegistered;
        _averageRating = rating;
        _feedbacks = feedbacks.take(5).toList();
        _questions = questions;
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
                          _buildQASection(),
                          if (_feedbacks.isNotEmpty) _buildFeedbackSection(),
                          const SizedBox(height: 100),
                        ],
                      ),
                    ),
                  ],
                ),
      bottomNavigationBar: _event != null ? _buildBottomBar() : null,
      floatingActionButton: _event != null
          ? FloatingActionButton.extended(
              onPressed: _showAIChat,
              backgroundColor: _getSocietyColor(),
              icon: const Icon(Icons.smart_toy),
              label: const Text('Ask AI'),
            )
          : null,
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
          onPressed: _shareEvent,
        ),
        IconButton(
          icon: const Icon(Icons.calendar_today),
          onPressed: _addToCalendar,
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
                    feedback.authorName.substring(0, 1).toUpperCase(),
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
                        feedback.authorName,
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
  
  // Q&A Section
  Future<List<EventQuestionModel>> _loadQuestions() async {
    try {
      final response = await SupabaseConfig.client
          .from('event_questions')
          .select('*')
          .eq('event_id', widget.eventId)
          .order('created_at', ascending: false)
          .limit(10);
          
      return (response as List)
          .map((json) => EventQuestionModel.fromJson(json))
          .toList();
    } catch (e) {
      AppLogger.error('Error loading questions', e);
      return [];
    }
  }
  
  Future<void> _postQuestion() async {
    if (_questionController.text.trim().isEmpty) return;
    
    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.user?.id;
    
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to post a question')),
      );
      return;
    }
    
    setState(() => _isPostingQuestion = true);
    
    try {
      await SupabaseConfig.client.from('event_questions').insert({
        'event_id': widget.eventId,
        'user_id': userId,
        'question': _questionController.text.trim(),
      });
      
      _questionController.clear();
      final questions = await _loadQuestions();
      
      if (!mounted) return;
      
      setState(() {
        _questions = questions;
        _isPostingQuestion = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Question posted!')),
      );
    } catch (e) {
      if (!mounted) return;
      
      setState(() => _isPostingQuestion = false);
      AppLogger.error('Error posting question', e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }
  
  Widget _buildQASection() {
    return Container(
      margin: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Questions & Answers',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${_questions.length} questions',
                style: const TextStyle(
                  color: AppColors.gray500,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Ask question input
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Have a question about this event?',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _questionController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'Ask your question here...',
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: AppColors.gray50,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isPostingQuestion ? null : _postQuestion,
                      icon: _isPostingQuestion
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send),
                      label: Text(_isPostingQuestion ? 'Posting...' : 'Post Question'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _getSocietyColor(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Questions list
          if (_questions.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.question_answer_outlined,
                        size: 48,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No questions yet',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Be the first to ask a question!',
                        style: TextStyle(
                          color: AppColors.gray500,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            ..._questions.map((question) => _buildQuestionCard(question)),
        ],
      ),
    );
  }
  
  Widget _buildQuestionCard(EventQuestionModel question) {
    final isExpanded = _expandedQuestionId == question.id;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          InkWell(
            onTap: () => _toggleQuestionExpansion(question.id),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: _getSocietyColor().withValues(alpha: 0.2),
                        child: Icon(
                          Icons.person,
                          size: 16,
                          color: _getSocietyColor(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              question.userName ?? 'Anonymous',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              _formatQuestionTime(question.createdAt),
                              style: const TextStyle(
                                color: AppColors.gray500,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (question.isAnswered)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Answered',
                            style: TextStyle(
                              color: AppColors.success,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      const SizedBox(width: 8),
                      Icon(
                        isExpanded ? Icons.expand_less : Icons.expand_more,
                        color: AppColors.gray600,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    question.question,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.thumb_up_outlined),
                        iconSize: 18,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => _upvoteQuestion(question.id),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${question.upvotes}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.gray600,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Icon(
                        Icons.comment_outlined,
                        size: 18,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${question.answerCount} answers',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.gray600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded) _buildAnswersSection(question),
        ],
      ),
    );
  }
  
  Widget _buildAnswersSection(EventQuestionModel question) {
    final answers = _questionAnswers[question.id] ?? [];
    
    return Container(
      decoration: BoxDecoration(
        color: AppColors.gray50,
        border: Border(
          top: BorderSide(
            color: AppColors.gray200,
            width: 1,
          ),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Answers list
          if (answers.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'No answers yet. Be the first to answer!',
                  style: TextStyle(
                    color: AppColors.gray500,
                    fontSize: 13,
                  ),
                ),
              ),
            )
          else
            ...answers.map((answer) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.gray200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                          child: const Icon(Icons.person, size: 12, color: AppColors.primary),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          answer['user_name'],
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          _formatQuestionTime(answer['created_at']),
                          style: const TextStyle(
                            color: AppColors.gray500,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      answer['answer'],
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            )),
          
          const SizedBox(height: 12),
          
          // Answer input
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _answerControllers.putIfAbsent(
                    question.id,
                    () => TextEditingController(),
                  ),
                  decoration: InputDecoration(
                    hintText: 'Write your answer...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  maxLines: 2,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(Icons.send, color: _getSocietyColor()),
                onPressed: () => _postAnswer(question.id),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Future<void> _toggleQuestionExpansion(String questionId) async {
    setState(() {
      if (_expandedQuestionId == questionId) {
        _expandedQuestionId = null;
      } else {
        _expandedQuestionId = questionId;
      }
    });
    
    // Load answers if expanding
    if (_expandedQuestionId == questionId && !_questionAnswers.containsKey(questionId)) {
      try {
        final answers = await _eventService.getQuestionAnswers(questionId);
        if (mounted) {
          setState(() {
            _questionAnswers[questionId] = answers;
          });
        }
      } catch (e) {
        AppLogger.error('Error loading answers', e);
      }
    }
  }
  
  Future<void> _postAnswer(String questionId) async {
    final controller = _answerControllers[questionId];
    if (controller == null || controller.text.trim().isEmpty) return;
    
    try {
      await _eventService.postAnswer(questionId, controller.text.trim());
      
      // Reload answers
      final answers = await _eventService.getQuestionAnswers(questionId);
      
      if (mounted) {
        controller.clear();
        setState(() {
          _questionAnswers[questionId] = answers;
        });
        
        // Reload questions to update answer count
        final questions = await _loadQuestions();
        setState(() {
          _questions = questions;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Answer posted!')),
        );
      }
    } catch (e) {
      AppLogger.error('Error posting answer', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error posting answer: $e')),
        );
      }
    }
  }
  
  Future<void> _upvoteQuestion(String questionId) async {
    try {
      await _eventService.upvoteQuestion(questionId);
      
      // Reload questions to update upvote count
      final questions = await _loadQuestions();
      
      if (mounted) {
        setState(() {
          _questions = questions;
        });
      }
    } catch (e) {
      AppLogger.error('Error upvoting question', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error upvoting: $e')),
        );
      }
    }
  }
  
  String _formatQuestionTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${difference.inDays ~/ 7}w ago';
    }
  }
  
  // AI Chat Methods
  void _showAIChat() {
    if (_event == null) return;
    
    // Initialize AI with event context
    _aiService.initSession();
    
    // Add initial context message
    if (_aiMessages.isEmpty) {
      _aiMessages.add(AIMessageModel.ai(
        "Hi! I'm your AI assistant. I can answer questions about \"${_event!.title}\". What would you like to know?"
      ));
    }
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildAIChatSheet(),
    );
  }
  
  Widget _buildAIChatSheet() {
    return StatefulBuilder(
      builder: (BuildContext context, StateSetter setModalState) {
        _modalStateSetter = setModalState; // Store the setter
        return DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _getSocietyColor().withValues(alpha: 0.1),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.smart_toy, color: _getSocietyColor()),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Ask AI About Event',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                _event!.title,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.gray600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  
                  // Messages
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      reverse: true, // Show latest messages at bottom
                      itemCount: _aiMessages.length,
                      itemBuilder: (context, index) {
                        // Reverse the index to show latest at bottom
                        final message = _aiMessages[_aiMessages.length - 1 - index];
                        return _buildAIMessageBubble(message);
                      },
                    ),
                  ),
                  
                  // Loading indicator
                  if (_isAIThinking)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _getSocietyColor(),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'AI is thinking...',
                            style: TextStyle(
                              color: AppColors.gray600,
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  // Input
                  Container(
                    padding: EdgeInsets.only(
                      left: 16,
                      right: 16,
                      top: 16,
                      bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                    ),
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
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _aiQuestionController,
                            decoration: InputDecoration(
                              hintText: 'Ask about the event...',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                              filled: true,
                              fillColor: AppColors.gray50,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                            ),
                            maxLines: 4,
                            minLines: 1,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _sendAIMessage(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        CircleAvatar(
                          backgroundColor: _getSocietyColor(),
                          child: IconButton(
                            icon: const Icon(Icons.send, color: Colors.white, size: 20),
                            onPressed: _isAIThinking ? null : _sendAIMessage,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
  
  Widget _buildAIMessageBubble(AIMessageModel message) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: message.isUser
              ? _getSocietyColor()
              : AppColors.gray100,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          message.content,
          style: TextStyle(
            color: message.isUser ? Colors.white : AppColors.gray900,
            fontSize: 14,
            height: 1.4,
          ),
        ),
      ),
    );
  }
  
  Future<void> _sendAIMessage() async {
    if (_aiQuestionController.text.trim().isEmpty || _isAIThinking) return;
    
    final userMessage = _aiQuestionController.text.trim();
    _aiQuestionController.clear();
    
    // Create event context for AI
    final eventContext = '''
Event Information:
- Title: ${_event!.title}
- Description: ${_event!.description}
- Date & Time: ${_formatDateTime(_event!.dateTime)}
- Venue: ${_event!.venue}
- Capacity: ${_event!.capacity} people
- Registered: ${_event!.registeredCount} people
- Type: ${_event!.eventType}
- Society: ${_event!.society?.name ?? 'N/A'}
${_event!.tags != null && _event!.tags!.isNotEmpty ? '- Tags: ${_event!.tags!.join(", ")}' : ''}

User Question: $userMessage

Please provide a helpful answer about this event. Be concise and friendly.
''';
    
    // Add user message and set thinking state
    _aiMessages.add(AIMessageModel.user(userMessage));
    _isAIThinking = true;
    
    // Update the modal UI
    _modalStateSetter?.call(() {});
    
    try {
      final response = await _aiService.sendMessage(eventContext);
      
      if (!mounted) return;
      
      // Add AI response and stop thinking
      _aiMessages.add(response);
      _isAIThinking = false;
      
      // Update the modal UI
      _modalStateSetter?.call(() {});
    } catch (e) {
      if (!mounted) return;
      
      AppLogger.error('AI error', e);
      
      // Add error message and stop thinking
      _aiMessages.add(AIMessageModel.ai(
        'Sorry, I encountered an error. Please try again.'
      ));
      _isAIThinking = false;
      
      // Update the modal UI
      _modalStateSetter?.call(() {});
    }
  }
  
  String _formatEventType(String type) {
    return type[0].toUpperCase() + type.substring(1);
  }
  
  // Add event to calendar
  Future<void> _addToCalendar() async {
    if (_event == null) return;
    
    try {
      final Event calendarEvent = Event(
        title: _event!.title,
        description: _event!.description,
        location: _event!.venue,
        startDate: _event!.dateTime,
        endDate: _event!.endTime ?? _event!.dateTime.add(const Duration(hours: 2)),
        iosParams: const IOSParams(
          reminder: Duration(hours: 1),
        ),
        androidParams: const AndroidParams(
          emailInvites: [],
        ),
      );

      await Add2Calendar.addEvent2Cal(calendarEvent);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event added to calendar!')),
        );
      }
    } catch (e) {
      AppLogger.error('Error adding to calendar', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding to calendar: $e')),
        );
      }
    }
  }
  
  // Share event
  Future<void> _shareEvent() async {
    if (_event == null) return;
    
    try {
      final String shareText = '''
🎉 ${_event!.title}

📅 ${_formatDateTime(_event!.dateTime)}
📍 ${_event!.venue}
🏛️ ${_event!.society?.name ?? 'Unknown'}

${_event!.description}

Register now on UniWeek app!
''';

      await Share.share(
        shareText,
        subject: _event!.title,
      );
    } catch (e) {
      AppLogger.error('Error sharing event', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sharing event: $e')),
        );
      }
    }
  }
  
  @override
  void dispose() {
    _questionController.dispose();
    _aiQuestionController.dispose();
    for (var controller in _answerControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }
}
