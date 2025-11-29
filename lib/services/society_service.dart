import '../core/config/supabase_config.dart';
import '../core/utils/logger.dart';
import '../models/society_model.dart';

class SocietyService {
  final _client = SupabaseConfig.client;

  // Get all societies
  Future<List<SocietyModel>> getAllSocieties() async {
    try {
      AppLogger.debug('Fetching all societies');
      final response = await _client
          .from('societies')
          .select()
          .order('name');

      final societies = (response as List)
          .map((json) => SocietyModel.fromJson(json))
          .toList();

      AppLogger.success('Fetched ${societies.length} societies');
      return societies;
    } catch (e) {
      AppLogger.error('Error fetching societies', e);
      rethrow;
    }
  }

  // Get society by ID
  Future<SocietyModel?> getSocietyById(String id) async {
    try {
      AppLogger.debug('Fetching society: $id');
      final response = await _client
          .from('societies')
          .select()
          .eq('id', id)
          .maybeSingle();

      if (response == null) {
        AppLogger.info('Society not found: $id');
        return null;
      }

      AppLogger.success('Fetched society: ${response['name']}');
      return SocietyModel.fromJson(response);
    } catch (e) {
      AppLogger.error('Error fetching society', e);
      rethrow;
    }
  }

  // Get society by code (ACM, CLS, CSS)
  Future<SocietyModel?> getSocietyByCode(String code) async {
    try {
      AppLogger.debug('Fetching society by code: $code');
      final response = await _client
          .from('societies')
          .select()
          .eq('code', code)
          .maybeSingle();

      if (response == null) {
        AppLogger.info('Society not found: $code');
        return null;
      }

      AppLogger.success('Fetched society: ${response['name']}');
      return SocietyModel.fromJson(response);
    } catch (e) {
      AppLogger.error('Error fetching society by code', e);
      rethrow;
    }
  }

  // Update society details (for admin/handler)
  Future<SocietyModel> updateSociety(String id, {
    String? description,
    String? logo,
    String? contactEmail,
    String? website,
  }) async {
    try {
      AppLogger.debug('Updating society: $id');
      
      final updates = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (description != null) updates['description'] = description;
      if (logo != null) updates['logo'] = logo;
      if (contactEmail != null) updates['contact_email'] = contactEmail;
      if (website != null) updates['website'] = website;

      final response = await _client
          .from('societies')
          .update(updates)
          .eq('id', id)
          .select()
          .single();

      AppLogger.success('Society updated: ${response['name']}');
      return SocietyModel.fromJson(response);
    } catch (e) {
      AppLogger.error('Error updating society', e);
      rethrow;
    }
  }

  // Get society statistics
  Future<Map<String, dynamic>> getSocietyStats(String societyId) async {
    try {
      AppLogger.debug('Fetching society stats: $societyId');
      
      // Get total events count
      final eventsCount = await _client
          .from('events')
          .select('id')
          .eq('society_id', societyId)
          .count();

      // Get total registrations count
      // First get all event IDs for this society
      final eventsResponse = await _client
          .from('events')
          .select('id')
          .eq('society_id', societyId);
      
      final eventIds = (eventsResponse as List)
          .map((e) => e['id'] as String)
          .toList();
      
      // Then count registrations for those events
      int registrationsTotalCount = 0;
      if (eventIds.isNotEmpty) {
        final registrationsCount = await _client
            .from('event_registrations')
            .select('id')
            .inFilter('event_id', eventIds)
            .count();
        registrationsTotalCount = registrationsCount.count;
      }

      // Get upcoming events count
      final upcomingCount = await _client
          .from('events')
          .select('id')
          .eq('society_id', societyId)
          .eq('status', 'upcoming')
          .count();

      final stats = {
        'total_events': eventsCount.count,
        'total_registrations': registrationsTotalCount,
        'upcoming_events': upcomingCount.count,
      };

      AppLogger.success('Fetched society stats');
      return stats;
    } catch (e) {
      AppLogger.error('Error fetching society stats', e);
      rethrow;
    }
  }

  // Get society handlers (users with role society_handler for this society)
  Future<List<Map<String, dynamic>>> getSocietyHandlers(String societyId) async {
    try {
      AppLogger.debug('Fetching society handlers: $societyId');
      final response = await _client
          .from('profiles')
          .select('id, full_name, email, avatar_url')
          .eq('society_id', societyId)
          .eq('role', 'society_handler');

      AppLogger.success('Fetched ${(response as List).length} handlers');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      AppLogger.error('Error fetching society handlers', e);
      rethrow;
    }
  }
}
