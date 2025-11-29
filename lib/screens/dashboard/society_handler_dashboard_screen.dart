import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/event_service.dart';
import '../../services/society_service.dart';
import '../../models/event_model.dart';
import '../../models/society_model.dart';
import '../../theme/app_colors.dart';
import '../../core/constants/constants.dart';
import '../../core/utils/logger.dart';
import '../../widgets/cards/stat_card.dart';

class SocietyHandlerDashboardScreen extends StatefulWidget {
  const SocietyHandlerDashboardScreen({super.key});

  @override
  State<SocietyHandlerDashboardScreen> createState() => _SocietyHandlerDashboardScreenState();
}

class _SocietyHandlerDashboardScreenState extends State<SocietyHandlerDashboardScreen> {
  final EventService _eventService = EventService();
  final SocietyService _societyService = SocietyService();
  
  SocietyModel? _society;
  List<EventModel> _societyEvents = [];
  Map<String, dynamic>? _societyStats;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    
    try {
      final authProvider = context.read<AuthProvider>();
      final societyId = authProvider.user?.societyId;

      if (societyId == null) {
        throw Exception('Society ID not found');
      }

      final society = await _societyService.getSocietyById(societyId);
      final events = await _eventService.getEvents(societyId: societyId);
      final stats = await _societyService.getSocietyStats(societyId);

      setState(() {
        _society = society;
        _societyEvents = events;
        _societyStats = stats;
        _isLoading = false;
      });
    } catch (e) {
      AppLogger.error('Error loading society dashboard', e);
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.user;

    return Scaffold(
      appBar: AppBar(
        title: Text(_society?.name ?? 'Society Dashboard'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadDashboardData,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildWelcomeSection(user?.fullName ?? 'Handler'),
                    const SizedBox(height: 24),

                    _buildStatsGrid(),
                    const SizedBox(height: 24),

                    _buildQuickActions(),
                    const SizedBox(height: 24),

                    _buildEventsSection(),
                    const SizedBox(height: 24),

                    _buildRecentActivity(),
                  ],
                ),
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.pushNamed(
            context,
            AppConstants.createEventRoute,
          );
          if (result == true) {
            _loadDashboardData();
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Create Event'),
        backgroundColor: _getSocietyColor(),
      ),
    );
  }

  Color _getSocietyColor() {
    if (_society == null) return AppColors.primary;
    switch (_society!.shortName) {
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

  Widget _buildWelcomeSection(String name) {
    final societyColor = _getSocietyColor();
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [societyColor, societyColor.withValues(alpha: 0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: societyColor.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getSocietyIcon(),
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _society?.name ?? 'Society',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Handler Dashboard',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white30),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.person, color: Colors.white70, size: 16),
              const SizedBox(width: 8),
              Text(
                'Welcome, $name',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.shield, color: Colors.white70, size: 16),
              const SizedBox(width: 8),
              Text(
                '${_society?.shortName ?? 'Society'} Handler',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _getSocietyIcon() {
    if (_society == null) return Icons.groups;
    switch (_society!.shortName) {
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

  Widget _buildStatsGrid() {
    if (_societyStats == null) return const SizedBox.shrink();

    final stats = [
      {
        'title': 'Total Events',
        'value': _societyStats!['total_events'].toString(),
        'icon': Icons.event,
        'color': AppColors.primary,
      },
      {
        'title': 'Registrations',
        'value': _societyStats!['total_registrations'].toString(),
        'icon': Icons.people,
        'color': AppColors.success,
      },
      {
        'title': 'Upcoming',
        'value': _societyStats!['upcoming_events'].toString(),
        'icon': Icons.calendar_today,
        'color': AppColors.warning,
      },
      {
        'title': 'Completed',
        'value': (_societyStats!['total_events'] - _societyStats!['upcoming_events']).toString(),
        'icon': Icons.check_circle,
        'color': AppColors.info,
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.3,
      ),
      itemCount: stats.length,
      itemBuilder: (context, index) {
        final stat = stats[index];
        return StatCard(
          title: stat['title'] as String,
          value: stat['value'] as String,
          icon: stat['icon'] as IconData,
          color: stat['color'] as Color,
        );
      },
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quick Actions', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
               child: _buildQuickActionCard(
                'Create Event',
                Icons.add_circle_outline,
                AppColors.primary,
                () async {
                  final result = await Navigator.pushNamed(
                    context,
                    AppConstants.createEventRoute,
                  );
                  if (result == true) {
                    _loadDashboardData();
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQuickActionCard(
                'View Events',
                Icons.event_note,
                AppColors.success,
                () {
                  // Navigate to society events list
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQuickActionCard(
                'Analytics',
                Icons.analytics_outlined,
                AppColors.warning,
                () {
                  Navigator.pushNamed(context, AppConstants.societyAnalyticsRoute);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActionCard(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventsSection() {
    final upcomingEvents = _societyEvents
        .where((e) => e.status == 'upcoming')
        .take(5)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Upcoming Events',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            TextButton(
              onPressed: () {
                // Navigate to all events
              },
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (upcomingEvents.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.event_busy,
                      size: 48,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No upcoming events',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () {
                        Navigator.pushNamed(context, AppConstants.createEventRoute);
                      },
                      child: const Text('Create your first event'),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: upcomingEvents.length,
            itemBuilder: (context, index) {
              return _buildEventCard(upcomingEvents[index]);
            },
          ),
      ],
    );
  }

  Widget _buildEventCard(EventModel event) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: () {
          Navigator.pushNamed(
            context,
            AppConstants.eventDetailRoute,
            arguments: event.id,
          );
        },
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: _getSocietyColor().withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.event,
            color: _getSocietyColor(),
          ),
        ),
        title: Text(
          event.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(_formatDate(event.dateTime)),
            const SizedBox(height: 4),
            Text(
              '${event.registeredCount} / ${event.capacity} registered',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        trailing: PopupMenuButton(
          icon: const Icon(Icons.more_vert),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'view',
              child: Row(
                children: [
                  Icon(Icons.visibility),
                  SizedBox(width: 8),
                  Text('View Details'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit),
                  SizedBox(width: 8),
                  Text('Edit Event'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'registrations',
              child: Row(
                children: [
                  Icon(Icons.people),
                  SizedBox(width: 8),
                  Text('View Registrations'),
                ],
              ),
            ),
          ],
          onSelected: (value) {
            switch (value) {
              case 'view':
                Navigator.pushNamed(
                  context,
                  AppConstants.eventDetailRoute,
                  arguments: event.id,
                );
                break;
              case 'edit':
                Navigator.pushNamed(
                  context,
                  AppConstants.editEventRoute,
                  arguments: event.id,
                );
                break;
              case 'registrations':
                Navigator.pushNamed(
                  context,
                  AppConstants.eventRegistrationsRoute,
                  arguments: event.id,
                );
                break;
            }
          },
        ),
      ),
    );
  }

  Widget _buildRecentActivity() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Activity',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildActivityItem(
                  Icons.person_add,
                  'New registration for Tech Workshop',
                  '2 hours ago',
                  AppColors.success,
                ),
                const Divider(),
                _buildActivityItem(
                  Icons.event,
                  'Event "Coding Challenge" created',
                  '5 hours ago',
                  AppColors.primary,
                ),
                const Divider(),
                _buildActivityItem(
                  Icons.check_circle,
                  'Event "Workshop 101" completed',
                  '1 day ago',
                  AppColors.info,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActivityItem(IconData icon, String title, String time, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  time,
                  style: const TextStyle(
                    color: AppColors.gray500,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final eventDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (eventDate == today) {
      return 'Today at ${_formatTime(dateTime)}';
    } else if (eventDate == today.add(const Duration(days: 1))) {
      return 'Tomorrow at ${_formatTime(dateTime)}';
    } else {
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[dateTime.month - 1]} ${dateTime.day}, ${_formatTime(dateTime)}';
    }
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:$minute $period';
  }
}
