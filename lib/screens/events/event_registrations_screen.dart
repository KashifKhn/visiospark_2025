import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../../models/registration_model.dart';
import '../../models/event_model.dart';
import '../../services/registration_service.dart';
import '../../services/event_service.dart';
import '../../theme/app_colors.dart';
import '../../core/utils/logger.dart';

class EventRegistrationsScreen extends StatefulWidget {
  final String eventId;

  const EventRegistrationsScreen({super.key, required this.eventId});

  @override
  State<EventRegistrationsScreen> createState() =>
      _EventRegistrationsScreenState();
}

class _EventRegistrationsScreenState extends State<EventRegistrationsScreen> {
  final RegistrationService _registrationService = RegistrationService();
  final EventService _eventService = EventService();

  EventModel? _event;
  List<RegistrationModel> _allRegistrations = [];
  List<RegistrationModel> _filteredRegistrations = [];
  String _searchQuery = '';
  String _filterStatus = 'all'; // all, registered, attended, cancelled
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _eventService.getEventById(widget.eventId),
        _registrationService.getEventRegistrations(widget.eventId),
      ]);

      setState(() {
        _event = results[0] as EventModel?;
        _allRegistrations = results[1] as List<RegistrationModel>;
        _applyFilters();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading registrations: $e')),
        );
      }
    }
  }

  void _applyFilters() {
    var filtered = _allRegistrations;

    // Filter by status
    if (_filterStatus != 'all') {
      filtered = filtered.where((reg) => reg.status == _filterStatus).toList();
    }

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((reg) {
        final userName = reg.user?.displayName;
        final userEmail = reg.user?.email;
        return (userName != null && userName.toLowerCase().contains(query)) || 
               (userEmail != null && userEmail.toLowerCase().contains(query));
      }).toList();
    }

    setState(() => _filteredRegistrations = filtered);
  }

  Future<void> _markAttendance(RegistrationModel registration) async {
    try {
      await _registrationService.markAsAttended(registration.id);
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Attendance marked successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error marking attendance: $e')),
        );
      }
    }
  }

  Future<void> _bulkMarkAttendance() async {
    final registeredCount = _allRegistrations
        .where((reg) => reg.status == 'registered')
        .length;

    if (registeredCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No pending registrations to mark')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark All as Attended'),
        content: Text(
          'Mark all $registeredCount registered participants as attended?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      setState(() => _isLoading = true);
      await _registrationService.bulkMarkAttendance(
        _allRegistrations
            .where((reg) => reg.status == 'registered')
            .map((reg) => reg.id)
            .toList(),
      );
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Marked $registeredCount participants as attended'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showExportOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.file_download),
              title: const Text('Export as CSV'),
              onTap: () {
                Navigator.pop(context);
                _exportData('csv');
              },
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Share List'),
              onTap: () {
                Navigator.pop(context);
                _exportData('share');
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportData(String format) async {
    try {
      // Prepare CSV data
      final List<List<dynamic>> rows = [
        ['Name', 'Email', 'Status', 'Registration Date'],
      ];
      
      for (final reg in _filteredRegistrations) {
        rows.add([
          reg.user?.displayName ?? 'N/A',
          reg.user?.email ?? 'N/A',
          reg.status,
          DateFormat('MMM dd, yyyy HH:mm').format(reg.registeredAt),
        ]);
      }
      
      final String csv = const ListToCsvConverter().convert(rows);
      
      if (format == 'csv') {
        // Save as file and share
        final directory = await getTemporaryDirectory();
        final file = File('${directory.path}/registrations_${_event?.title ?? 'event'}.csv');
        await file.writeAsString(csv);
        
        await Share.shareXFiles(
          [XFile(file.path)],
          subject: 'Event Registrations - ${_event?.title}',
        );
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('CSV file created and shared!')),
          );
        }
      } else if (format == 'share') {
        // Share as text
        final String shareText = '''
Event: ${_event?.title ?? 'Unknown'}
Total Registrations: ${_filteredRegistrations.length}

Registrations:
${_filteredRegistrations.map((reg) => '• ${reg.user?.displayName ?? 'N/A'} (${reg.status})').join('\n')}
''';
        
        await Share.share(
          shareText,
          subject: 'Event Registrations - ${_event?.title}',
        );
      }
    } catch (e) {
      AppLogger.error('Error exporting data', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error exporting: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Event Registrations'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download),
            tooltip: 'Export',
            onPressed: _showExportOptions,
          ),
        ],
      ),
      body: Column(
        children: [
          // Event Info Header
          if (_event != null) _buildEventHeader(isDark),

          // Stats Row
          if (!_isLoading) _buildStatsRow(),

          const Divider(height: 1),

          // Search and Filter
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Search bar
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search by name or email...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() {
                                _searchQuery = '';
                                _applyFilters();
                              });
                            },
                          )
                        : null,
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                      _applyFilters();
                    });
                  },
                ),

                const SizedBox(height: 12),

                // Filter chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('All', 'all'),
                      _buildFilterChip('Registered', 'registered'),
                      _buildFilterChip('Attended', 'attended'),
                      _buildFilterChip('Cancelled', 'cancelled'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Registrations List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredRegistrations.isEmpty
                    ? _buildEmptyState()
                    : _buildRegistrationsList(),
          ),
        ],
      ),
      floatingActionButton: _event != null &&
              !_event!.isUpcoming &&
              _allRegistrations
                  .any((reg) => reg.status == 'registered')
          ? FloatingActionButton.extended(
              onPressed: _bulkMarkAttendance,
              icon: const Icon(Icons.how_to_reg),
              label: const Text('Mark All Attended'),
            )
          : null,
    );
  }

  Widget _buildEventHeader(bool isDark) {
    final society = _event!.society;
    final societyColor = society != null
        ? Color(int.parse(society.color.replaceFirst('#', '0xFF')))
        : AppColors.primary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            societyColor.withValues(alpha: 0.1),
            societyColor.withValues(alpha: 0.05),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _event!.title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.calendar_today, size: 16, color: AppColors.gray500),
              const SizedBox(width: 8),
              Text(
                DateFormat('MMM dd, yyyy • hh:mm a').format(_event!.dateTime),
                style: TextStyle(color: AppColors.gray600),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.location_on, size: 16, color: AppColors.gray500),
              const SizedBox(width: 8),
              Text(
                _event!.venue,
                style: TextStyle(color: AppColors.gray600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    final registered =
        _allRegistrations.where((reg) => reg.status == 'registered').length;
    final attended =
        _allRegistrations.where((reg) => reg.status == 'attended').length;
    final cancelled =
        _allRegistrations.where((reg) => reg.status == 'cancelled').length;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatItem('Total', _allRegistrations.length, AppColors.primary),
          _buildStatItem('Registered', registered, AppColors.info),
          _buildStatItem('Attended', attended, AppColors.success),
          _buildStatItem('Cancelled', cancelled, AppColors.error),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, int value, Color color) {
    return Column(
      children: [
        Text(
          value.toString(),
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.gray600,
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filterStatus == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _filterStatus = value;
            _applyFilters();
          });
        },
      ),
    );
  }

  Widget _buildRegistrationsList() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _filteredRegistrations.length,
        itemBuilder: (context, index) {
          final registration = _filteredRegistrations[index];
          return _RegistrationCard(
            registration: registration,
            onMarkAttendance: registration.canMarkAttendance
                ? () => _markAttendance(registration)
                : null,
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 80, color: AppColors.gray400),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty
                ? 'No registrations match your search'
                : 'No registrations yet',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.gray500,
            ),
          ),
        ],
      ),
    );
  }
}

class _RegistrationCard extends StatelessWidget {
  final RegistrationModel registration;
  final VoidCallback? onMarkAttendance;

  const _RegistrationCard({
    required this.registration,
    this.onMarkAttendance,
  });

  @override
  Widget build(BuildContext context) {
    final user = registration.user;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getStatusColor().withValues(alpha: 0.2),
          child: Icon(
            _getStatusIcon(),
            color: _getStatusColor(),
          ),
        ),
        title: Text(
          user?.displayName ?? 'Unknown User',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (user?.email != null)
              Text(
                user!.email,
                style: TextStyle(fontSize: 12, color: AppColors.gray600),
              ),
            const SizedBox(height: 4),
            Text(
              'Registered: ${DateFormat('MMM dd, yyyy').format(registration.registeredAt)}',
              style: TextStyle(fontSize: 12, color: AppColors.gray500),
            ),
            if (registration.attendedAt != null)
              Text(
                'Attended: ${DateFormat('MMM dd, yyyy').format(registration.attendedAt!)}',
                style: TextStyle(fontSize: 12, color: AppColors.success),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildStatusBadge(),
            if (onMarkAttendance != null) ...[
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.check_circle_outline),
                tooltip: 'Mark Attended',
                color: AppColors.success,
                onPressed: onMarkAttendance,
              ),
            ],
          ],
        ),
        isThreeLine: true,
      ),
    );
  }

  Widget _buildStatusBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getStatusColor().withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        registration.status.toUpperCase(),
        style: TextStyle(
          color: _getStatusColor(),
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Color _getStatusColor() {
    switch (registration.status) {
      case 'attended':
        return AppColors.success;
      case 'cancelled':
        return AppColors.error;
      case 'registered':
      default:
        return AppColors.info;
    }
  }

  IconData _getStatusIcon() {
    switch (registration.status) {
      case 'attended':
        return Icons.check_circle;
      case 'cancelled':
        return Icons.cancel;
      case 'registered':
      default:
        return Icons.person;
    }
  }
}
