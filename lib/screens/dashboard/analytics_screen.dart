import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/event_service.dart';
import '../../services/society_service.dart';
import '../../models/event_model.dart';
import '../../theme/app_colors.dart';
import '../../core/utils/logger.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final EventService _eventService = EventService();
  final SocietyService _societyService = SocietyService();
  
  bool _isLoading = true;
  List<EventModel> _events = [];
  Map<String, dynamic>? _stats;
  Map<String, int> _eventsByMonth = {};
  Map<String, int> _eventsByType = {};

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() => _isLoading = true);
    
    try {
      final authProvider = context.read<AuthProvider>();
      final societyId = authProvider.user?.societyId;

      if (societyId == null) {
        throw Exception('Society ID not found');
      }

      final events = await _eventService.getEvents(societyId: societyId);
      final stats = await _societyService.getSocietyStats(societyId);
      
      // Process events by month (last 6 months)
      final eventsByMonth = <String, int>{};
      final now = DateTime.now();
      
      for (int i = 5; i >= 0; i--) {
        final month = DateTime(now.year, now.month - i, 1);
        final monthKey = '${month.month.toString().padLeft(2, '0')}/${month.year}';
        eventsByMonth[monthKey] = 0;
      }
      
      for (final event in events) {
        final monthKey = '${event.dateTime.month.toString().padLeft(2, '0')}/${event.dateTime.year}';
        if (eventsByMonth.containsKey(monthKey)) {
          eventsByMonth[monthKey] = (eventsByMonth[monthKey] ?? 0) + 1;
        }
      }
      
      // Process events by type
      final eventsByType = <String, int>{};
      for (final event in events) {
        eventsByType[event.eventType] = (eventsByType[event.eventType] ?? 0) + 1;
      }

      setState(() {
        _events = events;
        _stats = stats;
        _eventsByMonth = eventsByMonth;
        _eventsByType = eventsByType;
        _isLoading = false;
      });
    } catch (e) {
      AppLogger.error('Error loading analytics', e);
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics & Insights'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAnalytics,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildOverviewCards(),
                    const SizedBox(height: 24),
                    _buildEventsChart(),
                    const SizedBox(height: 24),
                    _buildEventTypesChart(),
                    const SizedBox(height: 24),
                    _buildTopEvents(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildOverviewCards() {
    if (_stats == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Overview',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Total Events',
                _stats!['total_events'].toString(),
                Icons.event,
                AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Total Registrations',
                _stats!['total_registrations'].toString(),
                Icons.people,
                AppColors.success,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Avg. Rating',
                _stats!['average_rating']?.toStringAsFixed(1) ?? '0.0',
                Icons.star,
                AppColors.warning,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Upcoming',
                _stats!['upcoming_events'].toString(),
                Icons.calendar_today,
                AppColors.info,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: color.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventsChart() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Events Over Time',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 200,
              child: _eventsByMonth.isEmpty
                  ? const Center(child: Text('No data available'))
                  : LineChart(
                      LineChartData(
                        gridData: FlGridData(show: true),
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 30,
                              getTitlesWidget: (value, meta) {
                                return Text(
                                  value.toInt().toString(),
                                  style: const TextStyle(fontSize: 10),
                                );
                              },
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 30,
                              getTitlesWidget: (value, meta) {
                                final index = value.toInt();
                                if (index >= 0 && index < _eventsByMonth.length) {
                                  final month = _eventsByMonth.keys.elementAt(index);
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      month.split('/')[0],
                                      style: const TextStyle(fontSize: 10),
                                    ),
                                  );
                                }
                                return const Text('');
                              },
                            ),
                          ),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        borderData: FlBorderData(show: true),
                        lineBarsData: [
                          LineChartBarData(
                            spots: _eventsByMonth.entries.map((e) {
                              final index = _eventsByMonth.keys.toList().indexOf(e.key);
                              return FlSpot(index.toDouble(), e.value.toDouble());
                            }).toList(),
                            isCurved: true,
                            color: AppColors.primary,
                            barWidth: 3,
                            dotData: const FlDotData(show: true),
                            belowBarData: BarAreaData(
                              show: true,
                              color: AppColors.primary.withValues(alpha: 0.2),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventTypesChart() {
    if (_eventsByType.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Events by Type',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sections: _eventsByType.entries.map((e) {
                    final color = _getTypeColor(e.key);
                    final total = _eventsByType.values.reduce((a, b) => a + b);
                    final percentage = (e.value / total * 100).toStringAsFixed(1);
                    
                    return PieChartSectionData(
                      value: e.value.toDouble(),
                      title: '$percentage%',
                      color: color,
                      radius: 80,
                      titleStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    );
                  }).toList(),
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: _eventsByType.entries.map((e) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: _getTypeColor(e.key),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${e.key} (${e.value})',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopEvents() {
    final sortedEvents = List<EventModel>.from(_events);
    sortedEvents.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final topEvents = sortedEvents.take(5).toList();

    if (topEvents.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent Events',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            ...topEvents.map((event) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _getTypeColor(event.eventType).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getEventIcon(event.eventType),
                      color: _getTypeColor(event.eventType),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${event.eventType} • ${_formatDate(event.dateTime)}',
                          style: const TextStyle(
                            color: AppColors.gray600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(event.status).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      event.status,
                      style: TextStyle(
                        color: _getStatusColor(event.status),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'workshop':
        return AppColors.primary;
      case 'competition':
        return AppColors.warning;
      case 'seminar':
        return AppColors.info;
      case 'social':
        return AppColors.success;
      default:
        return AppColors.gray600;
    }
  }

  IconData _getEventIcon(String type) {
    switch (type.toLowerCase()) {
      case 'workshop':
        return Icons.school;
      case 'competition':
        return Icons.emoji_events;
      case 'seminar':
        return Icons.person_pin_circle;
      case 'social':
        return Icons.celebration;
      default:
        return Icons.event;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'upcoming':
        return AppColors.info;
      case 'ongoing':
        return AppColors.success;
      case 'completed':
        return AppColors.gray600;
      case 'cancelled':
        return AppColors.error;
      default:
        return AppColors.gray600;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
