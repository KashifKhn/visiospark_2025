import '../core/config/supabase_config.dart';
import '../core/utils/logger.dart';
import '../models/registration_model.dart';

class RegistrationService {
  final _client = SupabaseConfig.client;

  // Register for an event
  Future<RegistrationModel> registerForEvent({
    required String eventId,
    required String userId,
    String? teamId,
  }) async {
    try {
      AppLogger.debug('Registering user for event: $eventId');
      
      // Check if already registered
      final existing = await _client
          .from('event_registrations')
          .select()
          .eq('event_id', eventId)
          .eq('user_id', userId)
          .maybeSingle();

      if (existing != null) {
        throw Exception('Already registered for this event');
      }

      // Check if event is full
      final event = await _client
          .from('events')
          .select('max_participants')
          .eq('id', eventId)
          .single();

      if (event['max_participants'] != null) {
        final registrationCount = await _client
            .from('event_registrations')
            .select('id')
            .eq('event_id', eventId)
            .eq('status', 'registered')
            .count();

        if (registrationCount.count >= event['max_participants']) {
          throw Exception('Event is full');
        }
      }

      final response = await _client
          .from('event_registrations')
          .insert({
            'event_id': eventId,
            'user_id': userId,
            'team_id': teamId,
            'status': 'registered',
            'registered_at': DateTime.now().toIso8601String(),
          })
          .select('*, events!inner(*, societies!inner(*)), profiles!inner(*)')
          .single();

      AppLogger.success('User registered for event');
      return RegistrationModel.fromJson(response);
    } catch (e) {
      AppLogger.error('Error registering for event', e);
      rethrow;
    }
  }

  // Cancel registration
  Future<void> cancelRegistration(String registrationId) async {
    try {
      AppLogger.debug('Cancelling registration: $registrationId');
      
      await _client
          .from('event_registrations')
          .update({
            'status': 'cancelled',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', registrationId);

      AppLogger.success('Registration cancelled');
    } catch (e) {
      AppLogger.error('Error cancelling registration', e);
      rethrow;
    }
  }

  // Mark as attended (for society handlers)
  Future<void> markAsAttended(String registrationId) async {
    try {
      AppLogger.debug('Marking registration as attended: $registrationId');
      
      await _client
          .from('event_registrations')
          .update({
            'status': 'attended',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', registrationId);

      AppLogger.success('Registration marked as attended');
    } catch (e) {
      AppLogger.error('Error marking as attended', e);
      rethrow;
    }
  }

  // Get user's registrations
  Future<List<RegistrationModel>> getUserRegistrations(String userId) async {
    try {
      AppLogger.debug('Fetching user registrations: $userId');
      
      final response = await _client
          .from('event_registrations')
          .select('*, events!inner(*, societies!inner(*)), profiles!inner(*)')
          .eq('user_id', userId)
          .order('registered_at', ascending: false);

      final registrations = (response as List)
          .map((json) => RegistrationModel.fromJson(json))
          .toList();

      AppLogger.success('Fetched ${registrations.length} registrations');
      return registrations;
    } catch (e) {
      AppLogger.error('Error fetching user registrations', e);
      rethrow;
    }
  }

  // Get event registrations (for society handlers)
  Future<List<RegistrationModel>> getEventRegistrations(String eventId) async {
    try {
      AppLogger.debug('Fetching event registrations: $eventId');
      
      final response = await _client
          .from('event_registrations')
          .select('*, events!inner(*, societies!inner(*)), profiles!inner(*)')
          .eq('event_id', eventId)
          .order('registered_at');

      final registrations = (response as List)
          .map((json) => RegistrationModel.fromJson(json))
          .toList();

      AppLogger.success('Fetched ${registrations.length} registrations');
      return registrations;
    } catch (e) {
      AppLogger.error('Error fetching event registrations', e);
      rethrow;
    }
  }

  // Check if user is registered for an event
  Future<bool> isUserRegistered(String eventId, String userId) async {
    try {
      AppLogger.debug('Checking registration status');
      
      final response = await _client
          .from('event_registrations')
          .select('id')
          .eq('event_id', eventId)
          .eq('user_id', userId)
          .maybeSingle();

      return response != null;
    } catch (e) {
      AppLogger.error('Error checking registration status', e);
      rethrow;
    }
  }

  // Get registration by ID
  Future<RegistrationModel?> getRegistrationById(String id) async {
    try {
      AppLogger.debug('Fetching registration: $id');
      
      final response = await _client
          .from('event_registrations')
          .select('*, events!inner(*, societies!inner(*)), profiles!inner(*)')
          .eq('id', id)
          .maybeSingle();

      if (response == null) {
        AppLogger.info('Registration not found');
        return null;
      }

      return RegistrationModel.fromJson(response);
    } catch (e) {
      AppLogger.error('Error fetching registration', e);
      rethrow;
    }
  }

  // Get user's upcoming events
  Future<List<RegistrationModel>> getUserUpcomingEvents(String userId) async {
    try {
      AppLogger.debug('Fetching user upcoming events: $userId');
      
      final response = await _client
          .from('event_registrations')
          .select('*, events!inner(*, societies!inner(*)), profiles!inner(*)')
          .eq('user_id', userId)
          .eq('status', 'registered')
          .gte('events.date_time', DateTime.now().toIso8601String())
          .order('registered_at', ascending: false);

      final registrations = (response as List)
          .map((json) => RegistrationModel.fromJson(json))
          .toList();

      // Sort by event date_time in memory
      registrations.sort((a, b) {
        if (a.event == null || b.event == null) return 0;
        return a.event!.dateTime.compareTo(b.event!.dateTime);
      });

      AppLogger.success('Fetched ${registrations.length} upcoming events');
      return registrations;
    } catch (e) {
      AppLogger.error('Error fetching upcoming events', e);
      rethrow;
    }
  }

  // Get user's past events
  Future<List<RegistrationModel>> getUserPastEvents(String userId) async {
    try {
      AppLogger.debug('Fetching user past events: $userId');
      
      final response = await _client
          .from('event_registrations')
          .select('*, events!inner(*, societies!inner(*)), profiles!inner(*)')
          .eq('user_id', userId)
          .lt('events.date_time', DateTime.now().toIso8601String())
          .order('registered_at', ascending: false);

      final registrations = (response as List)
          .map((json) => RegistrationModel.fromJson(json))
          .toList();

      // Sort by event date_time in memory (most recent first)
      registrations.sort((a, b) {
        if (a.event == null || b.event == null) return 0;
        return b.event!.dateTime.compareTo(a.event!.dateTime);
      });

      AppLogger.success('Fetched ${registrations.length} past events');
      return registrations;
    } catch (e) {
      AppLogger.error('Error fetching past events', e);
      rethrow;
    }
  }

  // Bulk mark attendance (scan QR codes)
  Future<List<String>> bulkMarkAttendance(List<String> registrationIds) async {
    try {
      AppLogger.debug('Bulk marking attendance for ${registrationIds.length} registrations');
      
      final response = await _client
          .from('event_registrations')
          .update({
            'status': 'attended',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .inFilter('id', registrationIds)
          .select('id');

      final updated = (response as List).map((r) => r['id'] as String).toList();
      
      AppLogger.success('Marked ${updated.length} registrations as attended');
      return updated;
    } catch (e) {
      AppLogger.error('Error bulk marking attendance', e);
      rethrow;
    }
  }
}
