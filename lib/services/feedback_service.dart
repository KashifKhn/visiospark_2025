import '../core/config/supabase_config.dart';
import '../core/utils/logger.dart';
import '../models/feedback_model.dart';

class FeedbackService {
  final _client = SupabaseConfig.client;

  // Submit feedback for an event
  Future<FeedbackModel> submitFeedback({
    required String eventId,
    required String userId,
    required int rating,
    String? comment,
  }) async {
    try {
      AppLogger.debug('Submitting feedback for event: $eventId');
      
      // Check if user registered for the event
      final registration = await _client
          .from('event_registrations')
          .select()
          .eq('event_id', eventId)
          .eq('user_id', userId)
          .maybeSingle();

      if (registration == null) {
        throw Exception('You must be registered for this event to submit feedback');
      }

      // Optional: Check attendance (commented for testing/demo purposes)
      // Uncomment for production to enforce attendance requirement
      // if (registration['status'] != 'attended') {
      //   throw Exception('You must attend the event to submit feedback');
      // }

      // Check if feedback already exists
      final existing = await _client
          .from('event_feedback')
          .select()
          .eq('event_id', eventId)
          .eq('user_id', userId)
          .maybeSingle();

      if (existing != null) {
        // Update existing feedback
        final response = await _client
            .from('event_feedback')
            .update({
              'rating': rating,
              'comment': comment,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', existing['id'])
            .select('*')
            .single();

        AppLogger.success('Feedback updated');
        return FeedbackModel.fromJson(response);
      } else {
        // Create new feedback
        final response = await _client
            .from('event_feedback')
            .insert({
              'event_id': eventId,
              'user_id': userId,
              'rating': rating,
              'comment': comment,
              'created_at': DateTime.now().toIso8601String(),
            })
            .select('*')
            .single();

        AppLogger.success('Feedback submitted');
        return FeedbackModel.fromJson(response);
      }
    } catch (e) {
      AppLogger.error('Error submitting feedback', e);
      rethrow;
    }
  }

  // Get event feedback (for society handlers)
  Future<List<FeedbackModel>> getEventFeedback(String eventId) async {
    try {
      AppLogger.debug('Fetching event feedback: $eventId');
      
      // Fetch feedback without profiles join (will be null in model)
      final response = await _client
          .from('event_feedback')
          .select('*')
          .eq('event_id', eventId)
          .order('created_at', ascending: false);

      final feedbacks = (response as List)
          .map((json) => FeedbackModel.fromJson(json))
          .toList();

      AppLogger.success('Fetched ${feedbacks.length} feedbacks');
      return feedbacks;
    } catch (e) {
      AppLogger.error('Error fetching event feedback', e);
      rethrow;
    }
  }

  // Get user's submitted feedback
  Future<List<FeedbackModel>> getUserFeedback(String userId) async {
    try {
      AppLogger.debug('Fetching user feedback: $userId');
      
      // Fetch feedback without profiles join
      final response = await _client
          .from('event_feedback')
          .select('*, events!inner(*, societies!inner(*))')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final feedbacks = (response as List)
          .map((json) => FeedbackModel.fromJson(json))
          .toList();

      AppLogger.success('Fetched ${feedbacks.length} feedbacks');
      return feedbacks;
    } catch (e) {
      AppLogger.error('Error fetching user feedback', e);
      rethrow;
    }
  }

  // Get feedback by ID
  Future<FeedbackModel?> getFeedbackById(String id) async {
    try {
      AppLogger.debug('Fetching feedback: $id');
      
      // Fetch feedback without profiles join
      final response = await _client
          .from('event_feedback')
          .select('*')
          .eq('id', id)
          .maybeSingle();

      if (response == null) {
        AppLogger.info('Feedback not found');
        return null;
      }

      return FeedbackModel.fromJson(response);
    } catch (e) {
      AppLogger.error('Error fetching feedback', e);
      rethrow;
    }
  }

  // Check if user has submitted feedback for event
  Future<FeedbackModel?> getUserEventFeedback(String eventId, String userId) async {
    try {
      AppLogger.debug('Checking user feedback for event');
      
      // Fetch feedback without profiles join
      final response = await _client
          .from('event_feedback')
          .select('*')
          .eq('event_id', eventId)
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) {
        return null;
      }

      return FeedbackModel.fromJson(response);
    } catch (e) {
      AppLogger.error('Error checking user feedback', e);
      rethrow;
    }
  }

  // Delete feedback
  Future<void> deleteFeedback(String id) async {
    try {
      AppLogger.debug('Deleting feedback: $id');
      
      await _client
          .from('event_feedback')
          .delete()
          .eq('id', id);

      AppLogger.success('Feedback deleted');
    } catch (e) {
      AppLogger.error('Error deleting feedback', e);
      rethrow;
    }
  }

  // Get event average rating
  Future<double> getEventAverageRating(String eventId) async {
    try {
      AppLogger.debug('Calculating average rating for event: $eventId');
      
      final response = await _client
          .from('event_feedback')
          .select('rating')
          .eq('event_id', eventId);

      final feedbacks = response as List;
      
      if (feedbacks.isEmpty) {
        return 0.0;
      }

      final total = feedbacks.map((f) => f['rating'] as int).reduce((a, b) => a + b);
      final average = total / feedbacks.length;

      AppLogger.success('Average rating: $average');
      return average;
    } catch (e) {
      AppLogger.error('Error calculating average rating', e);
      rethrow;
    }
  }

  // Get rating distribution for an event
  Future<Map<int, int>> getRatingDistribution(String eventId) async {
    try {
      AppLogger.debug('Fetching rating distribution for event: $eventId');
      
      final response = await _client
          .from('event_feedback')
          .select('rating')
          .eq('event_id', eventId);

      final feedbacks = response as List;
      
      final distribution = <int, int>{
        1: 0,
        2: 0,
        3: 0,
        4: 0,
        5: 0,
      };

      for (var feedback in feedbacks) {
        final rating = feedback['rating'] as int;
        distribution[rating] = (distribution[rating] ?? 0) + 1;
      }

      AppLogger.success('Rating distribution calculated');
      return distribution;
    } catch (e) {
      AppLogger.error('Error fetching rating distribution', e);
      rethrow;
    }
  }

  // Get society average rating (all events)
  Future<double> getSocietyAverageRating(String societyId) async {
    try {
      AppLogger.debug('Calculating average rating for society: $societyId');
      
      final response = await _client
          .from('event_feedback')
          .select('rating, events!inner(society_id)')
          .eq('events.society_id', societyId);

      final feedbacks = response as List;
      
      if (feedbacks.isEmpty) {
        return 0.0;
      }

      final total = feedbacks.map((f) => f['rating'] as int).reduce((a, b) => a + b);
      final average = total / feedbacks.length;

      AppLogger.success('Society average rating: $average');
      return average;
    } catch (e) {
      AppLogger.error('Error calculating society average rating', e);
      rethrow;
    }
  }

  // Get top-rated events
  Future<List<Map<String, dynamic>>> getTopRatedEvents({int limit = 10}) async {
    try {
      AppLogger.debug('Fetching top-rated events');
      
      // This is a simplified version - ideally you'd use a database view or function
      final response = await _client
          .from('event_feedback')
          .select('event_id, rating, events!inner(title, start_time, societies!inner(name))')
          .order('rating', ascending: false)
          .limit(limit);

      AppLogger.success('Fetched top-rated events');
      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      AppLogger.error('Error fetching top-rated events', e);
      rethrow;
    }
  }
}
