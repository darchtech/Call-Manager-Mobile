import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controller/lead_controller.dart';
import '../services/reminder_service.dart';
import '../widgets/reminder_dialog.dart';
import '../model/follow_up.dart';

class ReminderScreen extends StatefulWidget {
  const ReminderScreen({Key? key}) : super(key: key);

  @override
  State<ReminderScreen> createState() => _ReminderScreenState();
}

class _ReminderScreenState extends State<ReminderScreen> {
  final LeadController _leadController = LeadController.instance;
  final ReminderService _reminderService = ReminderService.instance;

  List<FollowUp> _scheduledReminders = [];
  List<FollowUp> _overdueReminders = [];
  List<FollowUp> _upcomingReminders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReminders();
  }

  Future<void> _loadReminders() async {
    setState(() => _isLoading = true);

    try {
      _scheduledReminders = _reminderService.getScheduledReminders();
      _overdueReminders = _reminderService.getOverdueReminders();
      _upcomingReminders = _reminderService.getUpcomingReminders();
    } catch (e) {
      Get.snackbar('Error', 'Failed to load reminders: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshReminders() async {
    await _loadReminders();
  }

  void _showReminderDialog({
    String? followUpId,
    String? leadId,
    required String leadName,
    DateTime? existingDate,
    String? existingMessage,
  }) {
    showDialog(
      context: context,
      builder: (context) => ReminderDialog(
        followUpId: followUpId,
        leadId: leadId,
        leadName: leadName,
        existingFollowUpDate: existingDate,
        existingMessage: existingMessage,
      ),
    ).then((_) => _refreshReminders());
  }

  Widget _buildReminderCard(FollowUp reminder, {bool isOverdue = false}) {
    final leadId = reminder.leadId;
    final lead = _leadController.getLeadById(leadId);
    final leadName = lead != null ? '${lead.firstName} ${lead.lastName}'.trim() : 'Lead';
    final followUpDate = reminder.dueAt;
    final message = reminder.note;
    final daysUntil = followUpDate.difference(DateTime.now()).inDays;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isOverdue ? Colors.red : Colors.orange,
          child: Icon(
            isOverdue ? Icons.warning : Icons.schedule,
            color: Colors.white,
          ),
        ),
        title: Text(
          leadName,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isOverdue ? Colors.red : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Follow-up: ${followUpDate.day}/${followUpDate.month}/${followUpDate.year}',
              style: TextStyle(
                color: isOverdue ? Colors.red : Colors.grey[600],
              ),
            ),
            if (message != null && message.isNotEmpty)
              Text(
                message,
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Colors.grey[600],
                ),
              ),
            if (daysUntil != null)
              Text(
                isOverdue
                    ? 'Overdue by ${-daysUntil} days'
                    : 'Due in $daysUntil days',
                style: TextStyle(
                  color: isOverdue ? Colors.red : Colors.blue,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) async {
            switch (value) {
              case 'edit':
                _showReminderDialog(
                  followUpId: reminder.id,
                  leadId: leadId,
                  leadName: leadName,
                  existingDate: followUpDate,
                  existingMessage: message,
                );
                break;
              case 'cancel':
                await _cancelReminder(reminder.id);
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [Icon(Icons.edit), SizedBox(width: 8), Text('Edit')],
              ),
            ),
            const PopupMenuItem(
              value: 'cancel',
              child: Row(
                children: [
                  Icon(Icons.cancel),
                  SizedBox(width: 8),
                  Text('Cancel'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _cancelReminder(String followUpId) async {
    try {
      await _reminderService.cancelFollowUpReminder(followUpId);
      Get.snackbar('Success', 'Follow-up cancelled successfully');
      await _refreshReminders();
    } catch (e) {
      Get.snackbar('Error', 'Failed to cancel reminder: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Follow-up Reminders'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshReminders,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refreshReminders,
              child: DefaultTabController(
                length: 3,
                child: Column(
                  children: [
                    const TabBar(
                      tabs: [
                        Tab(text: 'Scheduled'),
                        Tab(text: 'Overdue'),
                        Tab(text: 'Upcoming'),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          // Scheduled reminders
                          _scheduledReminders.isEmpty
                              ? const Center(
                                  child: Text('No scheduled reminders'),
                                )
                              : ListView.builder(
                                  itemCount: _scheduledReminders.length,
                                  itemBuilder: (context, index) {
                                    final reminder = _scheduledReminders[index];
                                    return _buildReminderCard(reminder);
                                  },
                                ),

                          // Overdue reminders
                          _overdueReminders.isEmpty
                              ? const Center(
                                  child: Text('No overdue reminders'),
                                )
                              : ListView.builder(
                                  itemCount: _overdueReminders.length,
                                  itemBuilder: (context, index) {
                                    final reminder = _overdueReminders[index];
                                    return _buildReminderCard(
                                      reminder,
                                      isOverdue: true,
                                    );
                                  },
                                ),

                          // Upcoming reminders
                          _upcomingReminders.isEmpty
                              ? const Center(
                                  child: Text('No upcoming reminders'),
                                )
                              : ListView.builder(
                                  itemCount: _upcomingReminders.length,
                                  itemBuilder: (context, index) {
                                    final reminder = _upcomingReminders[index];
                                    return _buildReminderCard(reminder);
                                  },
                                ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Show lead selection dialog
          _showLeadSelectionDialog();
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showLeadSelectionDialog() {
    final leads = _leadController.leads;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Lead'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: ListView.builder(
            itemCount: leads.length,
            itemBuilder: (context, index) {
              final lead = leads[index];
              return ListTile(
                title: Text('${lead.firstName} ${lead.lastName}'),
                subtitle: Text(lead.phoneNumber),
                onTap: () {
                  Navigator.pop(context);
                  _showReminderDialog(leadId: lead.id, leadName: '${lead.firstName} ${lead.lastName}');
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
