import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/feedback_model.dart';
import '../../models/event_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/feedback_service.dart';
import '../../services/event_service.dart';
import '../../theme/app_colors.dart';

class EventFeedbackScreen extends StatefulWidget {
  final String eventId;

  const EventFeedbackScreen({super.key, required this.eventId});

  @override
  State<EventFeedbackScreen> createState() => _EventFeedbackScreenState();
}

class _EventFeedbackScreenState extends State<EventFeedbackScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FeedbackService _feedbackService = FeedbackService();
  final EventService _eventService = EventService();

  EventModel? _event;
  List<FeedbackModel> _feedbacks = [];
  FeedbackModel? _myFeedback;
  bool _isLoading = true;

  // Form state
  int _selectedRating = 5;
  final _commentController = TextEditingController();
  bool _isAnonymous = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final authProvider = context.read<AuthProvider>();
      final userId = authProvider.user?.id;

      final results = await Future.wait([
        _eventService.getEventById(widget.eventId),
        _feedbackService.getEventFeedback(widget.eventId),
        if (userId != null)
          _feedbackService.getUserEventFeedback(widget.eventId, userId),
      ]);

      setState(() {
        _event = results[0] as EventModel?;
        _feedbacks = results[1] as List<FeedbackModel>;
        if (results.length > 2) {
          _myFeedback = results[2] as FeedbackModel?;
          if (_myFeedback != null) {
            _selectedRating = _myFeedback!.rating;
            _commentController.text = _myFeedback!.comment ?? '';
            _isAnonymous = _myFeedback!.isAnonymous;
          }
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading feedback: $e')),
        );
      }
    }
  }

  Future<void> _submitFeedback() async {
    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.user?.id;

    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to submit feedback')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Submit feedback (service handles create or update)
      await _feedbackService.submitFeedback(
        eventId: widget.eventId,
        userId: userId,
        rating: _selectedRating,
        comment: _commentController.text.trim().isEmpty
            ? null
            : _commentController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _myFeedback != null
                  ? 'Feedback updated successfully'
                  : 'Feedback submitted successfully',
            ),
          ),
        );
      }

      await _loadData();
      _tabController.animateTo(1); // Switch to reviews tab
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error submitting feedback: $e')),
        );
      }
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  Future<void> _deleteFeedback() async {
    if (_myFeedback == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Feedback'),
        content: const Text('Are you sure you want to delete your feedback?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _feedbackService.deleteFeedback(_myFeedback!.id);
      setState(() {
        _myFeedback = null;
        _selectedRating = 5;
        _commentController.clear();
        _isAnonymous = false;
      });
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Feedback deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting feedback: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Event Feedback'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Submit Feedback'),
            Tab(text: 'All Reviews'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildSubmitTab(),
                _buildReviewsTab(),
              ],
            ),
    );
  }

  Widget _buildSubmitTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Event info card
          if (_event != null) _buildEventCard(),

          const SizedBox(height: 24),

          // Rating section
          const Text(
            'How would you rate this event?',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                final rating = index + 1;
                return IconButton(
                  onPressed: () {
                    setState(() => _selectedRating = rating);
                  },
                  icon: Icon(
                    rating <= _selectedRating
                        ? Icons.star
                        : Icons.star_border,
                    size: 40,
                    color: AppColors.warning,
                  ),
                );
              }),
            ),
          ),
          Center(
            child: Text(
              _getRatingLabel(_selectedRating),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: _getRatingColor(_selectedRating),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Comment section
          const Text(
            'Share your experience (Optional)',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _commentController,
            decoration: const InputDecoration(
              hintText: 'Write your review...',
              border: OutlineInputBorder(),
            ),
            maxLines: 5,
            maxLength: 500,
          ),

          const SizedBox(height: 16),

          // Anonymous checkbox
          CheckboxListTile(
            value: _isAnonymous,
            onChanged: (value) {
              setState(() => _isAnonymous = value ?? false);
            },
            title: const Text('Submit anonymously'),
            subtitle: const Text(
              'Your name won\'t be shown with this review',
              style: TextStyle(fontSize: 12),
            ),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
          ),

          const SizedBox(height: 24),

          // Submit button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submitFeedback,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      _myFeedback != null
                          ? 'Update Feedback'
                          : 'Submit Feedback',
                    ),
            ),
          ),

          // Delete button (if existing feedback)
          if (_myFeedback != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _deleteFeedback,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Delete Feedback'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReviewsTab() {
    if (_feedbacks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.rate_review, size: 80, color: AppColors.gray400),
            const SizedBox(height: 16),
            Text(
              'No reviews yet',
              style: TextStyle(fontSize: 16, color: AppColors.gray500),
            ),
            const SizedBox(height: 8),
            const Text(
              'Be the first to share your experience!',
              style: TextStyle(fontSize: 14, color: AppColors.gray400),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Stats card
        _buildStatsCard(),
        const SizedBox(height: 16),
        const Text(
          'Reviews',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        // Reviews list
        ..._feedbacks.map((feedback) => _FeedbackCard(feedback: feedback)),
      ],
    );
  }

  Widget _buildEventCard() {
    final society = _event!.society;
    final societyColor = society != null
        ? Color(int.parse(society.color.replaceFirst('#', '0xFF')))
        : AppColors.primary;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (society != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: societyColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      society.shortName,
                      style: TextStyle(
                        color: societyColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _event!.title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              DateFormat('MMM dd, yyyy • hh:mm a').format(_event!.dateTime),
              style: TextStyle(fontSize: 14, color: AppColors.gray600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCard() {
    final avgRating = _event?.averageRating ?? 0.0;
    final totalReviews = _feedbacks.length;

    // Calculate rating distribution
    final distribution = <int, int>{1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
    for (final feedback in _feedbacks) {
      distribution[feedback.rating] = (distribution[feedback.rating] ?? 0) + 1;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                // Average rating
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        avgRating.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(5, (index) {
                          return Icon(
                            index < avgRating.floor()
                                ? Icons.star
                                : Icons.star_border,
                            color: AppColors.warning,
                            size: 20,
                          );
                        }),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$totalReviews reviews',
                        style: TextStyle(color: AppColors.gray600),
                      ),
                    ],
                  ),
                ),

                // Rating distribution
                Expanded(
                  flex: 2,
                  child: Column(
                    children: List.generate(5, (index) {
                      final rating = 5 - index;
                      final count = distribution[rating] ?? 0;
                      final percentage = totalReviews > 0
                          ? (count / totalReviews * 100)
                          : 0.0;

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            Text('$rating'),
                            const SizedBox(width: 4),
                            const Icon(Icons.star, size: 12, color: AppColors.warning),
                            const SizedBox(width: 8),
                            Expanded(
                              child: LinearProgressIndicator(
                                value: percentage / 100,
                                backgroundColor: AppColors.gray200,
                                valueColor: AlwaysStoppedAnimation(
                                  AppColors.warning,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 30,
                              child: Text(
                                '$count',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.gray600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getRatingLabel(int rating) {
    switch (rating) {
      case 5:
        return 'Excellent!';
      case 4:
        return 'Good';
      case 3:
        return 'Average';
      case 2:
        return 'Poor';
      case 1:
        return 'Terrible';
      default:
        return '';
    }
  }

  Color _getRatingColor(int rating) {
    if (rating >= 4) return AppColors.success;
    if (rating == 3) return AppColors.warning;
    return AppColors.error;
  }
}

class _FeedbackCard extends StatelessWidget {
  final FeedbackModel feedback;

  const _FeedbackCard({required this.feedback});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: feedback.sentimentColor.withValues(alpha: 0.2),
                  child: Text(
                    feedback.authorName[0].toUpperCase(),
                    style: TextStyle(
                      color: feedback.sentimentColor,
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
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Row(
                        children: [
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
                          const SizedBox(width: 8),
                          Text(
                            DateFormat('MMM dd, yyyy').format(feedback.createdAt),
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.gray500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Comment
            if (feedback.hasComment) ...[
              const SizedBox(height: 12),
              Text(
                feedback.comment!,
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
