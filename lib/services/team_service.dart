import '../core/config/supabase_config.dart';
import '../core/utils/logger.dart';
import '../models/team_model.dart';

class TeamService {
  final _client = SupabaseConfig.client;

  // Create a team
  Future<TeamModel> createTeam({
    required String eventId,
    required String name,
    required String userId,
    String? description,
    int maxMembers = 5,
  }) async {
    try {
      AppLogger.debug('Creating team: $name');
      
      // Create team
      final teamResponse = await _client
          .from('teams')
          .insert({
            'event_id': eventId,
            'name': name,
            'description': description,
            'max_members': maxMembers,
            'creator_id': userId,
          })
          .select()
          .single();

      final teamId = teamResponse['id'] as String;

      // Add creator as team leader
      await _client.from('team_members').insert({
        'team_id': teamId,
        'user_id': userId,
        'role': 'leader',
      });

      AppLogger.success('Team created: $name');
      return TeamModel.fromJson(teamResponse);
    } catch (e) {
      AppLogger.error('Error creating team', e);
      rethrow;
    }
  }

  // Get teams for an event
  Future<List<TeamModel>> getEventTeams(String eventId) async {
    try {
      AppLogger.debug('Fetching teams for event: $eventId');
      
      // First, get all teams
      final teamsResponse = await _client
          .from('teams')
          .select('*')
          .eq('event_id', eventId)
          .order('created_at', ascending: false);

      // Then get member counts separately
      final teams = <TeamModel>[];
      for (final teamJson in (teamsResponse as List)) {
        final teamId = teamJson['id'] as String;
        
        // Get member count for this team
        final membersResponse = await _client
            .from('team_members')
            .select('id')
            .eq('team_id', teamId);
        
        final memberCount = (membersResponse as List).length;
        
        final modifiedJson = Map<String, dynamic>.from(teamJson);
        modifiedJson['member_count'] = memberCount;
        
        teams.add(TeamModel.fromJson(modifiedJson));
      }

      AppLogger.success('Fetched ${teams.length} teams');
      return teams;
    } catch (e) {
      AppLogger.error('Error fetching teams', e);
      rethrow;
    }
  }

  // Get team details with members
  Future<TeamModel> getTeamDetails(String teamId) async {
    try {
      AppLogger.debug('Fetching team details: $teamId');
      
      final response = await _client
          .from('teams')
          .select('*, team_members(*, profiles(full_name, avatar_url, email)), events(title)')
          .eq('id', teamId)
          .single();

      AppLogger.success('Fetched team details');
      return TeamModel.fromJson(response);
    } catch (e) {
      AppLogger.error('Error fetching team details', e);
      rethrow;
    }
  }

  // Join a team
  Future<void> joinTeam(String teamId, String userId) async {
    try {
      AppLogger.debug('Joining team: $teamId');
      
      // Check if team is full
      final team = await _client
          .from('teams')
          .select('max_members')
          .eq('id', teamId)
          .single();

      // Get current member count
      final membersResponse = await _client
          .from('team_members')
          .select('id')
          .eq('team_id', teamId);
      
      final memberCount = (membersResponse as List).length;
      final maxMembers = team['max_members'] as int;

      if (memberCount >= maxMembers) {
        throw Exception('Team is full');
      }

      // Check if already a member
      final existing = await _client
          .from('team_members')
          .select()
          .eq('team_id', teamId)
          .eq('user_id', userId)
          .maybeSingle();

      if (existing != null) {
        throw Exception('Already a member of this team');
      }

      // Add member
      await _client.from('team_members').insert({
        'team_id': teamId,
        'user_id': userId,
        'role': 'member',
      });

      AppLogger.success('Joined team');
    } catch (e) {
      AppLogger.error('Error joining team', e);
      rethrow;
    }
  }

  // Leave a team
  Future<void> leaveTeam(String teamId, String userId) async {
    try {
      AppLogger.debug('Leaving team: $teamId');
      
      // Check if user is the leader
      final member = await _client
          .from('team_members')
          .select()
          .eq('team_id', teamId)
          .eq('user_id', userId)
          .single();

      if (member['role'] == 'leader') {
        // If leader is leaving, check if there are other members
        final allMembers = await _client
            .from('team_members')
            .select()
            .eq('team_id', teamId);

        if ((allMembers as List).length > 1) {
          throw Exception('Leader cannot leave team with members. Transfer leadership or disband team first.');
        }
        
        // If leader is the only member, delete the team
        await _client.from('teams').delete().eq('id', teamId);
      } else {
        // Remove member
        await _client
            .from('team_members')
            .delete()
            .eq('team_id', teamId)
            .eq('user_id', userId);
      }

      AppLogger.success('Left team');
    } catch (e) {
      AppLogger.error('Error leaving team', e);
      rethrow;
    }
  }

  // Get user's teams
  Future<List<TeamModel>> getUserTeams(String userId) async {
    try {
      AppLogger.debug('Fetching user teams: $userId');
      
      final response = await _client
          .from('team_members')
          .select('*, teams(*, events(title), team_members(count))')
          .eq('user_id', userId)
          .order('joined_at', ascending: false);

      final teams = (response as List).map((json) {
        final teamData = json['teams'] as Map<String, dynamic>;
        
        // Count members
        final membersData = teamData['team_members'] as List?;
        final memberCount = membersData?.isNotEmpty == true 
            ? membersData!.length 
            : 0;
        
        final modifiedJson = Map<String, dynamic>.from(teamData);
        modifiedJson['member_count'] = memberCount;
        
        return TeamModel.fromJson(modifiedJson);
      }).toList();

      AppLogger.success('Fetched ${teams.length} teams');
      return teams;
    } catch (e) {
      AppLogger.error('Error fetching user teams', e);
      rethrow;
    }
  }

  // Send message to team
  Future<TeamMessageModel> sendMessage({
    required String teamId,
    required String userId,
    required String message,
  }) async {
    try {
      AppLogger.debug('Sending message to team: $teamId');
      
      final response = await _client
          .from('team_messages')
          .insert({
            'team_id': teamId,
            'user_id': userId,
            'message': message,
          })
          .select('*, profiles(full_name, avatar_url)')
          .single();

      AppLogger.success('Message sent');
      return TeamMessageModel.fromJson(response);
    } catch (e) {
      AppLogger.error('Error sending message', e);
      rethrow;
    }
  }

  // Get team messages
  Future<List<TeamMessageModel>> getTeamMessages(String teamId) async {
    try {
      AppLogger.debug('Fetching team messages: $teamId');
      
      final response = await _client
          .from('team_messages')
          .select('*, profiles(full_name, avatar_url)')
          .eq('team_id', teamId)
          .order('created_at', ascending: true)
          .limit(100);

      final messages = (response as List)
          .map((json) => TeamMessageModel.fromJson(json))
          .toList();

      AppLogger.success('Fetched ${messages.length} messages');
      return messages;
    } catch (e) {
      AppLogger.error('Error fetching messages', e);
      rethrow;
    }
  }

  // Subscribe to team messages (real-time)
  Stream<List<TeamMessageModel>> subscribeToTeamMessages(String teamId) {
    return _client
        .from('team_messages')
        .stream(primaryKey: ['id'])
        .eq('team_id', teamId)
        .order('created_at')
        .map((data) => data
            .map((json) => TeamMessageModel.fromJson(json))
            .toList());
  }

  // Delete team (only by leader)
  Future<void> deleteTeam(String teamId) async {
    try {
      AppLogger.debug('Deleting team: $teamId');
      
      await _client.from('teams').delete().eq('id', teamId);

      AppLogger.success('Team deleted');
    } catch (e) {
      AppLogger.error('Error deleting team', e);
      rethrow;
    }
  }

  // Update registration with team
  Future<void> updateRegistrationTeam({
    required String eventId,
    required String userId,
    required String teamId,
  }) async {
    try {
      AppLogger.debug('Updating registration with team');
      
      await _client
          .from('event_registrations')
          .update({'team_id': teamId})
          .eq('event_id', eventId)
          .eq('user_id', userId);

      AppLogger.success('Registration updated with team');
    } catch (e) {
      AppLogger.error('Error updating registration', e);
      rethrow;
    }
  }
}
