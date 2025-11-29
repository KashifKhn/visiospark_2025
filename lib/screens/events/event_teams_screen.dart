import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/team_model.dart';
import '../../models/event_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/team_service.dart';
import '../../services/event_service.dart';
import '../../theme/app_colors.dart';
import '../../core/utils/logger.dart';
import '../chat/team_chat_screen.dart';

class EventTeamsScreen extends StatefulWidget {
  final String eventId;

  const EventTeamsScreen({
    super.key,
    required this.eventId,
  });

  @override
  State<EventTeamsScreen> createState() => _EventTeamsScreenState();
}

class _EventTeamsScreenState extends State<EventTeamsScreen> {
  final _teamService = TeamService();
  final _eventService = EventService();
  final _teamNameController = TextEditingController();
  final _teamDescController = TextEditingController();
  
  EventModel? _event;
  List<TeamModel> _teams = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _teamNameController.dispose();
    _teamDescController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final event = await _eventService.getEventById(widget.eventId);
      final teams = await _teamService.getEventTeams(widget.eventId);
      
      if (!mounted) return;
      setState(() {
        _event = event;
        _teams = teams;
        _isLoading = false;
      });
    } catch (e) {
      AppLogger.error('Error loading data', e);
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _createTeam() async {
    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.user?.id;

    if (userId == null) return;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Team'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _teamNameController,
              decoration: const InputDecoration(
                labelText: 'Team Name',
                hintText: 'Enter team name',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _teamDescController,
              decoration: const InputDecoration(
                labelText: 'Description (Optional)',
                hintText: 'Brief team description',
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (_teamNameController.text.trim().isNotEmpty) {
                Navigator.pop(context, {
                  'name': _teamNameController.text.trim(),
                  'description': _teamDescController.text.trim(),
                });
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (result == null || !mounted) return;

    try {
      final team = await _teamService.createTeam(
        eventId: widget.eventId,
        name: result['name'],
        userId: userId,
        description: result['description'].isEmpty ? null : result['description'],
      );

      // Update registration with team
      await _teamService.updateRegistrationTeam(
        eventId: widget.eventId,
        userId: userId,
        teamId: team.id,
      );

      _teamNameController.clear();
      _teamDescController.clear();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Team created successfully!')),
      );

      await _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating team: $e')),
      );
    }
  }

  Future<void> _joinTeam(TeamModel team) async {
    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.user?.id;

    if (userId == null) return;

    try {
      await _teamService.joinTeam(team.id, userId);
      
      // Update registration with team
      await _teamService.updateRegistrationTeam(
        eventId: widget.eventId,
        userId: userId,
        teamId: team.id,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Joined team successfully!')),
      );

      await _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error joining team: $e')),
      );
    }
  }

  void _openTeamChat(TeamModel team) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TeamChatScreen(teamId: team.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Event Teams'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Event info
                if (_event != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _event!.title,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Form teams to collaborate on this event',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),

                // Teams list
                Expanded(
                  child: _teams.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.group_off,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No teams yet',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Be the first to create a team!',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: Colors.grey,
                                    ),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadData,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _teams.length,
                            itemBuilder: (context, index) {
                              final team = _teams[index];
                              return _buildTeamCard(team);
                            },
                          ),
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createTeam,
        icon: const Icon(Icons.add),
        label: const Text('Create Team'),
      ),
    );
  }

  Widget _buildTeamCard(TeamModel team) {
    final authProvider = context.watch<AuthProvider>();
    final userId = authProvider.user?.id;
    
    final isMember = team.members?.any((m) => m.userId == userId) ?? false;
    final isLeader = team.members?.any((m) => m.userId == userId && m.isLeader) ?? false;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        team.name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      if (team.description != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          team.description!,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ],
                  ),
                ),
                Column(
                  children: [
                    Icon(
                      team.isFull ? Icons.lock : Icons.group,
                      color: team.isFull ? Colors.grey : AppColors.primary,
                    ),
                    Text(
                      '${team.memberCount ?? 0}/${team.maxMembers}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (isMember) ...[
                  if (isLeader)
                    Chip(
                      label: const Text('Leader'),
                      avatar: const Icon(Icons.star, size: 16),
                      backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                    ),
                  if (!isLeader)
                    Chip(
                      label: const Text('Member'),
                      avatar: const Icon(Icons.check, size: 16),
                      backgroundColor: Colors.green.withValues(alpha: 0.2),
                    ),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: () => _openTeamChat(team),
                    icon: const Icon(Icons.chat, size: 18),
                    label: const Text('Chat'),
                  ),
                ] else ...[
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: team.isFull ? null : () => _joinTeam(team),
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(team.isFull ? 'Full' : 'Join'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
