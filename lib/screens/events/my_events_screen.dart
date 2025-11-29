import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/registration_model.dart';
import '../../models/society_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/registration_service.dart';
import '../../services/society_service.dart';
import '../../theme/app_colors.dart';
import '../../core/constants/constants.dart';
import 'package:intl/intl.dart';

// Import route constants
const String eventDetailRoute = AppConstants.eventDetailRoute;
const String eventsRoute = AppConstants.eventsRoute;

class MyEventsScreen extends StatefulWidget {
  const MyEventsScreen({super.key});

  @override
  State<MyEventsScreen> createState() => _MyEventsScreenState();
}

class _MyEventsScreenState extends State<MyEventsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final RegistrationService _registrationService = RegistrationService();
  final SocietyService _societyService = SocietyService();

  List<RegistrationModel> _allRegistrations = [];
  List<SocietyModel> _societies = [];
  String? _selectedSocietyId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final authProvider = context.read<AuthProvider>();
      final userId = authProvider.user?.id;

      if (userId == null) return;

      // Load registrations and societies in parallel
      final results = await Future.wait([
        _registrationService.getUserRegistrations(userId),
        _societyService.getAllSocieties(),
      ]);

      setState(() {
        _allRegistrations = results[0] as List<RegistrationModel>;
        _societies = results[1] as List<SocietyModel>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading events: $e')),
        );
      }
    }
  }

  List<RegistrationModel> _getFilteredRegistrations() {
    var filtered = _allRegistrations;

    // Filter by society
    if (_selectedSocietyId != null) {
      filtered = filtered
          .where((reg) => reg.event?.societyId == _selectedSocietyId)
          .toList();
    }

    // Filter by tab
    final now = DateTime.now();
    switch (_tabController.index) {
      case 0: // Upcoming
        return filtered
            .where((reg) =>
                reg.isRegistered &&
                reg.event != null &&
                reg.event!.dateTime.isAfter(now))
            .toList()
          ..sort((a, b) => a.event!.dateTime.compareTo(b.event!.dateTime));

      case 1: // Past
        return filtered
            .where((reg) =>
                (reg.isAttended || reg.isRegistered) &&
                reg.event != null &&
                reg.event!.dateTime.isBefore(now))
            .toList()
          ..sort((a, b) => b.event!.dateTime.compareTo(a.event!.dateTime));

      case 2: // Cancelled
        return filtered.where((reg) => reg.isCancelled).toList()
          ..sort((a, b) => (b.cancelledAt ?? DateTime.now())
              .compareTo(a.cancelledAt ?? DateTime.now()));

      default:
        return [];
    }
  }

  Future<void> _cancelRegistration(RegistrationModel registration) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Registration'),
        content: Text(
          'Are you sure you want to cancel your registration for "${registration.event?.title ?? 'this event'}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _registrationService.cancelRegistration(registration.id);
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registration cancelled successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cancelling registration: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Events'),
        bottom: TabBar(
          controller: _tabController,
          onTap: (_) => setState(() {}),
          tabs: const [
            Tab(text: 'Upcoming'),
            Tab(text: 'Past'),
            Tab(text: 'Cancelled'),
          ],
        ),
        actions: [
          // Society filter
          PopupMenuButton<String?>(
            icon: Icon(
              _selectedSocietyId != null
                  ? Icons.filter_alt
                  : Icons.filter_alt_outlined,
            ),
            tooltip: 'Filter by Society',
            onSelected: (value) {
              setState(() => _selectedSocietyId = value);
            },
            itemBuilder: (context) => [
              PopupMenuItem<String?>(
                value: null,
                child: Row(
                  children: [
                    Icon(
                      _selectedSocietyId == null
                          ? Icons.check_circle
                          : Icons.circle_outlined,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    const Text('All Societies'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              ..._societies.map((society) {
                final isSelected = _selectedSocietyId == society.id;
                return PopupMenuItem<String?>(
                  value: society.id,
                  child: Row(
                    children: [
                      Icon(
                        isSelected
                            ? Icons.check_circle
                            : Icons.circle_outlined,
                        size: 20,
                        color: Color(int.parse(society.color.replaceFirst('#', '0xFF'))),
                      ),
                      const SizedBox(width: 12),
                      Text(society.shortName),
                    ],
                  ),
                );
              }),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: _buildEventsList(isDark),
            ),
    );
  }

  Widget _buildEventsList(bool isDark) {
    final registrations = _getFilteredRegistrations();

    if (registrations.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: registrations.length,
      itemBuilder: (context, index) {
        final registration = registrations[index];
        final event = registration.event;

        if (event == null) {
          return const SizedBox.shrink();
        }

        final society = event.society;
        final societyColor = society != null
            ? Color(int.parse(society.color.replaceFirst('#', '0xFF')))
            : AppColors.primary;

        return _EventCard(
          registration: registration,
          societyColor: societyColor,
          isDark: isDark,
          onTap: () {
            Navigator.pushNamed(
              context,
              eventDetailRoute,
              arguments: event.id,
            ).then((_) => _loadData());
          },
          onCancel: registration.canCancel
              ? () => _cancelRegistration(registration)
              : null,
        );
      },
    );
  }

  Widget _buildEmptyState() {
    String message;
    IconData icon;

    switch (_tabController.index) {
      case 0:
        message = _selectedSocietyId != null
            ? 'No upcoming events for this society'
            : 'No upcoming events\nBrowse events to register!';
        icon = Icons.event_available;
        break;
      case 1:
        message = _selectedSocietyId != null
            ? 'No past events for this society'
            : 'No past events yet';
        icon = Icons.history;
        break;
      case 2:
        message = 'No cancelled registrations';
        icon = Icons.event_busy;
        break;
      default:
        message = 'No events found';
        icon = Icons.event_note;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: AppColors.gray400),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: AppColors.gray500,
            ),
          ),
          if (_tabController.index == 0) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pushNamed(context, eventsRoute);
              },
              icon: const Icon(Icons.explore),
              label: const Text('Browse Events'),
            ),
          ],
        ],
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  final RegistrationModel registration;
  final Color societyColor;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback? onCancel;

  const _EventCard({
    required this.registration,
    required this.societyColor,
    required this.isDark,
    required this.onTap,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final event = registration.event!;
    final society = event.society;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image header
            if (event.imageUrl != null)
              Stack(
                children: [
                  Image.network(
                    event.imageUrl!,
                    height: 150,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        _buildPlaceholderImage(societyColor),
                  ),
                  // Status badge
                  Positioned(
                    top: 12,
                    right: 12,
                    child: _buildStatusBadge(),
                  ),
                ],
              )
            else
              Stack(
                children: [
                  _buildPlaceholderImage(societyColor),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: _buildStatusBadge(),
                  ),
                ],
              ),

            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Society badge
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

                  const SizedBox(height: 8),

                  // Title
                  Text(
                    event.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 12),

                  // Date & Time
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 16,
                        color: AppColors.gray500,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        DateFormat('MMM dd, yyyy • hh:mm a')
                            .format(event.dateTime),
                        style: TextStyle(
                          color: AppColors.gray600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Venue
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 16,
                        color: AppColors.gray500,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          event.venue,
                          style: TextStyle(
                            color: AppColors.gray600,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                  // Registered date
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 16,
                        color: AppColors.success,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Registered on ${DateFormat('MMM dd, yyyy').format(registration.registeredAt)}',
                        style: TextStyle(
                          color: AppColors.gray500,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),

                  // Actions
                  if (onCancel != null) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: onCancel,
                        icon: const Icon(Icons.cancel),
                        label: const Text('Cancel Registration'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: const BorderSide(color: AppColors.error),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderImage(Color color) {
    return Container(
      height: 150,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.6),
            color.withValues(alpha: 0.3),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.event,
          size: 60,
          color: Colors.white.withValues(alpha: 0.8),
        ),
      ),
    );
  }

  Widget _buildStatusBadge() {
    Color bgColor;
    Color textColor;
    String text;
    IconData icon;

    if (registration.isCancelled) {
      bgColor = AppColors.error;
      textColor = Colors.white;
      text = 'Cancelled';
      icon = Icons.cancel;
    } else if (registration.isAttended) {
      bgColor = AppColors.success;
      textColor = Colors.white;
      text = 'Attended';
      icon = Icons.check_circle;
    } else if (registration.event!.isUpcoming) {
      bgColor = AppColors.info;
      textColor = Colors.white;
      text = 'Upcoming';
      icon = Icons.schedule;
    } else {
      bgColor = AppColors.gray600;
      textColor = Colors.white;
      text = 'Completed';
      icon = Icons.event_available;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: textColor),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
