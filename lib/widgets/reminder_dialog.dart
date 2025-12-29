import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controller/lead_controller.dart';
import '../services/reminder_service.dart';
import '../services/follow_up_service.dart';
// removed unused imports

class ReminderDialog extends StatefulWidget {
  final String? followUpId; // for edit/cancel
  final String? leadId; // required for create
  final String leadName;
  final DateTime? existingFollowUpDate;
  final String? existingMessage;

  const ReminderDialog({
    Key? key,
    this.followUpId,
    this.leadId,
    required this.leadName,
    this.existingFollowUpDate,
    this.existingMessage,
  }) : super(key: key);

  @override
  State<ReminderDialog> createState() => _ReminderDialogState();
}

class _ReminderDialogState extends State<ReminderDialog> {
  final _formKey = GlobalKey<FormState>();
  final _messageController = TextEditingController();
  final _followUpService = Get.find<FollowUpService>();
  DateTime? _selectedDate;
  int _reminderIntervalDays = 7;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.existingFollowUpDate;
    _messageController.text = widget.existingMessage ?? '';
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _saveReminder() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDate == null) {
      Get.snackbar('Error', 'Please select a follow-up date');
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (widget.followUpId != null) {
        // Update existing follow-up
        await ReminderService.instance.updateFollowUpReminder(
          followUpId: widget.followUpId!,
          newFollowUpDate: _selectedDate!,
          newMessage: _messageController.text.trim().isEmpty
              ? null
              : _messageController.text.trim(),
        );
        Get.snackbar('Success', 'Follow-up updated successfully');
      } else {
        // Create new follow-up (requires leadId)
        if (widget.leadId == null) {
          Get.snackbar('Error', 'Lead is required to create follow-up');
        } else {
          // Create follow-up using FollowUpService (handles both server creation and FCM scheduling)
          final followUp = await _followUpService.createFollowUp(
            leadId: widget.leadId!,
            dueAt: _selectedDate!,
            note: _messageController.text.trim().isEmpty
                ? null
                : _messageController.text.trim(),
          );

          if (followUp != null) {
            Get.snackbar('Success', 'Follow-up scheduled successfully');
          } else {
            Get.snackbar('Error', 'Failed to create follow-up');
          }
        }
      }

      // Refresh lead data
      await LeadController.instance.loadLeads();

      Get.back();
    } catch (e) {
      Get.snackbar('Error', 'Failed to save reminder: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _cancelReminder() async {
    setState(() => _isLoading = true);

    try {
      if (widget.followUpId == null) return;
      await ReminderService.instance.cancelFollowUpReminder(widget.followUpId!);
      Get.snackbar('Success', 'Follow-up cancelled successfully');

      // Refresh lead data
      await LeadController.instance.loadLeads();

      Get.back();
    } catch (e) {
      Get.snackbar('Error', 'Failed to cancel reminder: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.followUpId != null ? 'Update Follow-up' : 'Schedule Follow-up',
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Lead: ${widget.leadName}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),

              // Follow-up date
              Text(
                'Follow-up Date *',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: _selectDate,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today),
                      const SizedBox(width: 8),
                      Text(
                        _selectedDate != null
                            ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                            : 'Select date',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Reminder interval
              Text(
                'Reminder Interval (days)',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                value: _reminderIntervalDays,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                items: const [
                  DropdownMenuItem(value: 1, child: Text('1 day')),
                  DropdownMenuItem(value: 3, child: Text('3 days')),
                  DropdownMenuItem(value: 7, child: Text('7 days')),
                  DropdownMenuItem(value: 14, child: Text('14 days')),
                  DropdownMenuItem(value: 30, child: Text('30 days')),
                ],
                onChanged: (value) {
                  setState(() {
                    _reminderIntervalDays = value ?? 7;
                  });
                },
              ),
              const SizedBox(height: 16),

              // Message
              Text(
                'Reminder Message (optional)',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _messageController,
                maxLines: 3,
                maxLength: 500,
                decoration: const InputDecoration(
                  hintText: 'Enter a custom message for the reminder...',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value != null && value.length > 500) {
                    return 'Message cannot exceed 500 characters';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        if (widget.followUpId != null)
          TextButton(
            onPressed: _isLoading ? null : _cancelReminder,
            child: const Text('Cancel Follow-up'),
          ),
        TextButton(
          onPressed: _isLoading ? null : () => Get.back(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveReminder,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  widget.existingFollowUpDate != null ? 'Update' : 'Schedule',
                ),
        ),
      ],
    );
  }
}
