import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sizer/sizer.dart';
import '../model/lead.dart';
import '../services/follow_up_service.dart';
import '../utils/app_colors_new.dart';
import '../utils/text_styles_new.dart';
import '../utils/date_utils.dart' as AppDateUtils;
import '../widgets/toastification.dart';
import 'package:toastification/toastification.dart';

class FollowUpDialog extends StatefulWidget {
  final Lead lead;

  const FollowUpDialog({super.key, required this.lead});

  @override
  State<FollowUpDialog> createState() => _FollowUpDialogState();
}

class _FollowUpDialogState extends State<FollowUpDialog> {
  final FollowUpService _followUpService = Get.find<FollowUpService>();
  final TextEditingController _noteController = TextEditingController();
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _selectedTime = const TimeOfDay(hour: 9, minute: 0);
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Set default time to 9:00 AM tomorrow in IST
    final nowIST = AppDateUtils.DateUtils.toIST(DateTime.now());
    final tomorrowIST = nowIST.add(const Duration(days: 1));
    _selectedDate = DateTime(
      tomorrowIST.year,
      tomorrowIST.month,
      tomorrowIST.day,
    );
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: EdgeInsets.symmetric(horizontal: 0.5.w),
      contentPadding: EdgeInsets.all(5.w),
      // titlePadding: EdgeInsets.fromLTRB(6.w, 6.w, 6.w, 2.h),
      // actionsPadding: EdgeInsets.fromLTRB(6.w, 2.h, 6.w, 6.w),
      title: Row(
        children: [
          Icon(Icons.schedule, color: AppColors.primary, size: 6.w),
          SizedBox(width: 2.w),
          Expanded(
            child: Text(
              'Schedule Follow-up',
              style: TextStyles.heading3.copyWith(
                color: AppColors.primary,
                fontSize: 18.sp,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Lead info
            Container(
              padding: EdgeInsets.all(4.w),
              decoration: BoxDecoration(
                color: AppColors.lightBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 5.w,
                    backgroundColor: AppColors.primary.withOpacity(0.1),
                    child: Text(
                      widget.lead.displayName.isNotEmpty
                          ? widget.lead.displayName[0].toUpperCase()
                          : '?',
                      style: TextStyles.body.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 16.sp,
                      ),
                    ),
                  ),
                  SizedBox(width: 3.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.lead.displayName,
                          style: TextStyles.body.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 16.sp,
                          ),
                        ),
                        SizedBox(height: 0.5.h),
                        Text(
                          widget.lead.formattedPhoneNumber,
                          style: TextStyles.caption.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 14.sp,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 4.h),

            // Date and Time Selection
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Calendar',
                        style: TextStyles.body.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 18.sp,
                        ),
                      ),
                      SizedBox(height: 1.h),
                      InkWell(
                        onTap: _selectDate,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 3.w,
                            vertical: 1.5.h,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.border),
                            borderRadius: BorderRadius.circular(8),
                            color: AppColors.lightBackground,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.calendar_today,
                                color: AppColors.primary,
                                size: 4.w,
                              ),
                              SizedBox(width: 2.w),
                              Text(
                                '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                                style: TextStyles.body.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 3.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Time',
                        style: TextStyles.body.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 18.sp,
                        ),
                      ),
                      SizedBox(height: 1.h),
                      InkWell(
                        onTap: _selectTime,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 3.w,
                            vertical: 1.5.h,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.border),
                            borderRadius: BorderRadius.circular(8),
                            color: AppColors.lightBackground,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.access_time,
                                color: AppColors.primary,
                                size: 4.w,
                              ),
                              SizedBox(width: 2.w),
                              Text(
                                _selectedTime.format(context),
                                style: TextStyles.body.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 3.h),

            // Note field
            Text(
              'Note (Optional)',
              style: TextStyles.body.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 18.sp,
              ),
            ),
            SizedBox(height: 1.h),
            TextField(
              controller: _noteController,
              style: TextStyles.body.copyWith(fontSize: 16.sp),
              decoration: InputDecoration(
                hintText: 'Add a note...',
                hintStyle: TextStyles.body.copyWith(
                  fontSize: 16.sp,
                  color: AppColors.textSecondary,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 3.w,
                  vertical: 1.5.h,
                ),
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(
            padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.5.h),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            'Cancel',
            style: TextStyles.body.copyWith(
              color: AppColors.textSecondary,
              fontSize: 16.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _createFollowUp,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.5.h),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 2,
          ),
          child: _isLoading
              ? SizedBox(
                  width: 5.w,
                  height: 5.w,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(
                  'Schedule',
                  style: TextStyles.body.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 16.sp,
                  ),
                ),
        ),
      ],
    );
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppColors.textPrimary,
            ),

            datePickerTheme: DatePickerThemeData(
              headerHelpStyle: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
              ),
              headerHeadlineStyle: TextStyle(
                fontSize: 24.sp,
                fontWeight: FontWeight.w600,
              ),
              dayStyle: TextStyle(fontSize: 16.sp),
              weekdayStyle: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
              ),
              yearStyle: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
              ),
              cancelButtonStyle: TextButton.styleFrom(
                textStyle: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              confirmButtonStyle: TextButton.styleFrom(
                textStyle: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
            timePickerTheme: TimePickerThemeData(
              hourMinuteTextStyle: TextStyle(
                fontSize: 23.sp,
                fontWeight: FontWeight.w600,
              ),
              hourMinuteColor: AppColors.primary.withOpacity(0.1),
              dialHandColor: AppColors.primary,
              entryModeIconColor: AppColors.primary,
              dayPeriodColor: AppColors.primary.withOpacity(0.7),
              dayPeriodBorderSide: BorderSide(
                color: const Color.fromARGB(255, 50, 118, 219).withOpacity(0.7),
              ),
              helpTextStyle: TextStyle(
                fontSize: 22.sp,
                fontWeight: FontWeight.w600,
              ),
              dayPeriodTextStyle: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
              ),
              dialTextStyle: TextStyle(fontSize: 15.sp),
              confirmButtonStyle: TextButton.styleFrom(
                textStyle: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                ),
                foregroundColor: AppColors.primary,
              ),
              cancelButtonStyle: TextButton.styleFrom(
                textStyle: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                ),
                foregroundColor: AppColors.primary,
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<void> _createFollowUp() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Combine date and time (this is in IST)
      final istDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      // Convert IST to UTC for server
      // Since istDateTime is local time (IST), we need to convert it to UTC
      final utcDateTime = istDateTime.toUtc();

      print('[FollowUpDialog] 📝 Creating follow-up:');
      print(
        '[FollowUpDialog] - Lead: ${widget.lead.displayName} (${widget.lead.id})',
      );
      print('[FollowUpDialog] - Due at (IST): $istDateTime');
      print('[FollowUpDialog] - Due at (UTC): $utcDateTime');
      print('[FollowUpDialog] - Note: ${_noteController.text}');

      final followUp = await _followUpService.createFollowUp(
        leadId: widget.lead.id,
        dueAt: utcDateTime,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
      );

      if (followUp != null) {
        print(
          '[FollowUpDialog] ✅ Follow-up created successfully: ${followUp.id}',
        );

        ToastHelper.showToast(
          context: context,
          message: 'Follow-up scheduled successfully!',
          type: ToastificationType.success,
        );

        // Close dialog
        Navigator.of(context).pop(followUp);
      } else {
        print('[FollowUpDialog] ❌ Failed to create follow-up');

        ToastHelper.showToast(
          context: context,
          message: 'Failed to schedule follow-up. Please try again.',
          type: ToastificationType.error,
        );
      }
    } catch (e) {
      print('[FollowUpDialog] ❌ Error creating follow-up: $e');

      ToastHelper.showToast(
        context: context,
        message: 'Error scheduling follow-up: $e',
        type: ToastificationType.error,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
