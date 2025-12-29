import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sizer/sizer.dart';
import '../model/follow_up.dart';
import '../services/follow_up_service.dart';
import '../utils/app_colors_new.dart';
import '../utils/text_styles_new.dart';
import '../utils/date_utils.dart' as AppDateUtils;
import '../widgets/toastification.dart';
import 'package:toastification/toastification.dart';

class EditFollowUpDialog extends StatefulWidget {
  final FollowUp followUp;

  const EditFollowUpDialog({super.key, required this.followUp});

  @override
  State<EditFollowUpDialog> createState() => _EditFollowUpDialogState();
}

class _EditFollowUpDialogState extends State<EditFollowUpDialog> {
  final FollowUpService _followUpService = Get.find<FollowUpService>();
  final TextEditingController _noteController = TextEditingController();
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Initialize with current follow-up values converted to IST for display
    final istDateTime = AppDateUtils.DateUtils.toIST(widget.followUp.dueAt);
    _selectedDate = istDateTime;
    _selectedTime = TimeOfDay.fromDateTime(istDateTime);
    _noteController.text = widget.followUp.note ?? '';
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
      title: Row(
        children: [
          Icon(Icons.edit, color: AppColors.primary, size: 6.w),
          SizedBox(width: 2.w),
          Expanded(
            child: Text(
              'Edit Follow-up',
              style: TextStyles.heading3.copyWith(
                color: AppColors.primary,
                fontSize: 18.sp,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
          // Note Field
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
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: TextStyles.body.copyWith(
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _updateFollowUp,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.5.h),
          ),
          child: _isLoading
              ? SizedBox(
                  width: 4.w,
                  height: 4.w,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(
                  'Update',
                  style: TextStyles.body.copyWith(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
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

  Future<void> _updateFollowUp() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      print(
        '[EditFollowUpDialog] 📝 Updating follow-up: ${widget.followUp.id}',
      );

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

      // Validate future date (check against IST current time)
      // DateTime.now() returns local device time, which should already be IST
      final nowLocal = DateTime.now();

      // Create a clean DateTime for comparison (without seconds/milliseconds)
      final selectedIST = DateTime(
        istDateTime.year,
        istDateTime.month,
        istDateTime.day,
        istDateTime.hour,
        istDateTime.minute,
      );
      final currentLocal = DateTime(
        nowLocal.year,
        nowLocal.month,
        nowLocal.day,
        nowLocal.hour,
        nowLocal.minute,
      );

      print('[EditFollowUpDialog] 🕐 Time validation:');
      print('[EditFollowUpDialog] - Selected IST: $selectedIST');
      print('[EditFollowUpDialog] - Current Local: $currentLocal');
      print(
        '[EditFollowUpDialog] - Is after: ${selectedIST.isAfter(currentLocal)}',
      );

      if (!selectedIST.isAfter(currentLocal)) {
        ToastHelper.showToast(
          context: context,
          message: 'Follow-up time must be in the future',
          type: ToastificationType.error,
        );
        return;
      }

      // Update follow-up with UTC time
      final updatedFollowUp = await _followUpService.updateFollowUp(
        followUpId: widget.followUp.id,
        dueAt: utcDateTime,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
      );

      if (updatedFollowUp != null) {
        ToastHelper.showToast(
          context: context,
          message: 'Follow-up updated successfully',
          type: ToastificationType.success,
        );
        Navigator.pop(context, updatedFollowUp);
      } else {
        ToastHelper.showToast(
          context: context,
          message: 'Failed to update follow-up',
          type: ToastificationType.error,
        );
      }
    } catch (e) {
      print('[EditFollowUpDialog] ❌ Error updating follow-up: $e');
      ToastHelper.showToast(
        context: context,
        message: 'Error updating follow-up: $e',
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
