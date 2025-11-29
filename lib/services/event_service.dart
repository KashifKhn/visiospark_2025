import '../core/config/supabase_config.dart';
import '../core/utils/logger.dart';
import '../models/event_model.dart';

class EventService {
  final _client = SupabaseConfig.client;

  // Get all events with optional filters
  Future<List<EventModel>> getEvents({
    String? societyId,
    String? status,
    String? eventType,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      AppLogger.debug('Fetching events with filters');
      var query = _client
          .from('events')
          .select('*, societies!inner(*)');

      if (societyId != null) {
        query = query.eq('society_id', societyId);
      }

      if (status != null) {
        query = query.eq('status', status);
      }

      if (eventType != null) {
        query = query.eq('event_type', eventType);
      }

      if (startDate != null) {
        query = query.gte('date_time', startDate.toIso8601String());
      }

      if (endDate != null) {
        query = query.lte('date_time', endDate.toIso8601String());
      }

      final response = await query.order('date_time');

      final events = (response as List)
          .map((json) => EventModel.fromJson(json))
          .toList();

      AppLogger.success('Fetched ${events.length} events');
      return events;
    } catch (e) {
      AppLogger.error('Error fetching events', e);
      rethrow;
    }
  }

  // Get event by ID
  Future<EventModel?> getEventById(String id) async {
    try {
      AppLogger.debug('Fetching event: $id');
      final response = await _client
          .from('events')
          .select('*, societies!inner(*)')
          .eq('id', id)
          .maybeSingle();

      if (response == null) {
        AppLogger.info('Event not found: $id');
        return null;
      }

      AppLogger.success('Fetched event: ${response['title']}');
      return EventModel.fromJson(response);
    } catch (e) {
      AppLogger.error('Error fetching event', e);
      rethrow;
    }
  }

  // Get upcoming events
  Future<List<EventModel>> getUpcomingEvents({String? societyId}) async {
    try {
      AppLogger.debug('Fetching upcoming events');
      var query = _client
          .from('events')
          .select('*, societies!inner(*)')
          .eq('status', 'upcoming')
          .gte('date_time', DateTime.now().toIso8601String());

      if (societyId != null) {
        query = query.eq('society_id', societyId);
      }

      final response = await query.order('date_time');

      final events = (response as List)
          .map((json) => EventModel.fromJson(json))
          .toList();

      AppLogger.success('Fetched ${events.length} upcoming events');
      return events;
    } catch (e) {
      AppLogger.error('Error fetching upcoming events', e);
      rethrow;
    }
  }

  // Create new event (society handler only)
  Future<EventModel> createEvent({
    required String title,
    required String description,
    required String societyId,
    required DateTime startTime,
    required DateTime endTime,
    required String location,
    required String eventType,
    int? maxParticipants,
    String? imageUrl,
    List<String>? tags,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      AppLogger.debug('Creating new event: $title');
      
      final response = await _client
          .from('events')
          .insert({
            'title': title,
            'description': description,
            'society_id': societyId,
            'date_time': startTime.toIso8601String(),
            'end_time': endTime.toIso8601String(),
            'venue': location,
            'event_type': eventType,
            'capacity': maxParticipants ?? 100,
            'image_url': imageUrl,
            'tags': tags,
            'status': 'upcoming',
            'created_by': SupabaseConfig.currentUserId!,
            'created_at': DateTime.now().toIso8601String(),
          })
          .select('*, societies!inner(*)')
          .single();

      AppLogger.success('Event created: ${response['title']}');
      return EventModel.fromJson(response);
    } catch (e) {
      AppLogger.error('Error creating event', e);
      rethrow;
    }
  }

  // Update event
  Future<EventModel> updateEvent(
    String id, {
    String? title,
    String? description,
    DateTime? startTime,
    DateTime? endTime,
    String? location,
    String? eventType,
    int? maxParticipants,
    String? status,
    String? imageUrl,
    List<String>? tags,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      AppLogger.debug('Updating event: $id');
      
      final updates = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (title != null) updates['title'] = title;
      if (description != null) updates['description'] = description;
      if (startTime != null) updates['date_time'] = startTime.toIso8601String();
      if (endTime != null) updates['end_time'] = endTime.toIso8601String();
      if (location != null) updates['venue'] = location;
      if (eventType != null) updates['event_type'] = eventType;
      if (maxParticipants != null) updates['capacity'] = maxParticipants;
      if (status != null) updates['status'] = status;
      if (imageUrl != null) updates['image_url'] = imageUrl;
      if (tags != null) updates['tags'] = tags;

      final response = await _client
          .from('events')
          .update(updates)
          .eq('id', id)
          .select('*, societies!inner(*)')
          .single();

      AppLogger.success('Event updated: ${response['title']}');
      return EventModel.fromJson(response);
    } catch (e) {
      AppLogger.error('Error updating event', e);
      rethrow;
    }
  }

  // Delete event
  Future<void> deleteEvent(String id) async {
    try {
      AppLogger.debug('Deleting event: $id');
      await _client
          .from('events')
          .delete()
          .eq('id', id);

      AppLogger.success('Event deleted: $id');
    } catch (e) {
      AppLogger.error('Error deleting event', e);
      rethrow;
    }
  }

  // Cancel event
  Future<EventModel> cancelEvent(String id, String reason) async {
    try {
      AppLogger.debug('Cancelling event: $id');
      
      final response = await _client
          .from('events')
          .update({
            'status': 'cancelled',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', id)
          .select('*, societies!inner(*)')
          .single();

      AppLogger.success('Event cancelled: ${response['title']}');
      return EventModel.fromJson(response);
    } catch (e) {
      AppLogger.error('Error cancelling event', e);
      rethrow;
    }
  }

  // Get events by user interests (personalized recommendations)
  Future<List<EventModel>> getRecommendedEvents(List<String> interests) async {
    try {
      AppLogger.debug('Fetching recommended events for interests: $interests');
      
      final response = await _client
          .from('events')
          .select('*, societies!inner(*)')
          .eq('status', 'upcoming')
          .gte('date_time', DateTime.now().toIso8601String())
          .overlaps('tags', interests)
          .order('date_time')
          .limit(20);

      final events = (response as List)
          .map((json) => EventModel.fromJson(json))
          .toList();

      AppLogger.success('Fetched ${events.length} recommended events');
      return events;
    } catch (e) {
      AppLogger.error('Error fetching recommended events', e);
      rethrow;
    }
  }

  // Search events by title or description
  Future<List<EventModel>> searchEvents(String query) async {
    try {
      AppLogger.debug('Searching events: $query');
      
      final response = await _client
          .from('events')
          .select('*, societies!inner(*)')
          .or('title.ilike.%$query%,description.ilike.%$query%')
          .order('date_time');

      final events = (response as List)
          .map((json) => EventModel.fromJson(json))
          .toList();

      AppLogger.success('Found ${events.length} events');
      return events;
    } catch (e) {
      AppLogger.error('Error searching events', e);
      rethrow;
    }
  }

  // Get event statistics
  Future<Map<String, dynamic>> getEventStats(String eventId) async {
    try {
      AppLogger.debug('Fetching event stats: $eventId');
      
      // Get registrations count
      final registrationsCount = await _client
          .from('event_registrations')
          .select('id')
          .eq('event_id', eventId)
          .eq('status', 'registered')
          .count();

      // Get attended count
      final attendedCount = await _client
          .from('event_registrations')
          .select('id')
          .eq('event_id', eventId)
          .eq('status', 'attended')
          .count();

      // Get feedback count and average rating
      final feedbackResponse = await _client
          .from('event_feedback')
          .select('rating')
          .eq('event_id', eventId);

      final feedbacks = feedbackResponse as List;
      final avgRating = feedbacks.isEmpty
          ? 0.0
          : feedbacks.map((f) => f['rating'] as int).reduce((a, b) => a + b) / feedbacks.length;

      final stats = {
        'total_registrations': registrationsCount.count,
        'total_attended': attendedCount.count,
        'total_feedback': feedbacks.length,
        'average_rating': avgRating,
      };

      AppLogger.success('Fetched event stats');
      return stats;
    } catch (e) {
      AppLogger.error('Error fetching event stats', e);
      rethrow;
    }
  }

  // Get answers for a question
  Future<List<Map<String, dynamic>>> getQuestionAnswers(String questionId) async {
    try {
      AppLogger.debug('Fetching answers for question: $questionId');
      
      final response = await _client
          .from('event_answers')
          .select('*, profiles(full_name)')
          .eq('question_id', questionId)
          .order('created_at', ascending: true);

      final answers = response as List;
      
      AppLogger.success('Fetched ${answers.length} answers');
      return answers.map((a) => {
        'id': a['id'],
        'answer': a['answer'],
        'user_name': a['profiles']?['full_name'] ?? 'Anonymous',
        'created_at': DateTime.parse(a['created_at']),
      }).toList();
    } catch (e) {
      AppLogger.error('Error fetching answers', e);
      rethrow;
    }
  }

  // Post an answer to a question
  Future<void> postAnswer(String questionId, String answer) async {
    try {
      AppLogger.debug('Posting answer to question: $questionId');
      
      await _client.from('event_answers').insert({
        'question_id': questionId,
        'answer': answer,
        'user_id': _client.auth.currentUser!.id,
      });

      AppLogger.success('Answer posted successfully');
    } catch (e) {
      AppLogger.error('Error posting answer', e);
      rethrow;
    }
  }

  // Upvote a question
  Future<void> upvoteQuestion(String questionId) async {
    try {
      AppLogger.debug('Upvoting question: $questionId');
      
      // Get current upvote count
      final question = await _client
          .from('event_questions')
          .select('upvotes')
          .eq('id', questionId)
          .single();
      
      final currentUpvotes = question['upvotes'] as int;
      
      // Increment upvote count
      await _client
          .from('event_questions')
          .update({'upvotes': currentUpvotes + 1})
          .eq('id', questionId);
      
      AppLogger.success('Question upvoted');
    } catch (e) {
      AppLogger.error('Error upvoting question', e);
      rethrow;
    }
  }
}
