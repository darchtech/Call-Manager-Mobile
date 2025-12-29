import '../model/lead.dart';
import '../repository/lead_repository.dart';

class DataSeedingService {
  static final LeadRepository _leadRepo = LeadRepository.instance;

  /// Seed sample data for development/testing
  static Future<void> seedSampleData() async {
    try {
      print('[DataSeeding] Starting to seed sample data...');

      // Check if data already exists
      final existingLeads = _leadRepo.getAllLeads();
      if (existingLeads.isNotEmpty) {
        print('[DataSeeding] Sample data already exists, skipping...');
        return;
      }

      // Create sample status options
      await _createSampleStatusOptions();

      // Create sample leads
      await _createSampleLeads();

      print('[DataSeeding] Sample data seeded successfully');
    } catch (e) {
      print('[DataSeeding] Error seeding sample data: $e');
    }
  }

  /// Create sample status options
  static Future<void> _createSampleStatusOptions() async {
    // Lead status options
    final leadStatusOptions = [
      LeadStatus(name: 'New', type: 'leadStatus', color: '#2196F3', order: 1),
      LeadStatus(
        name: 'Contacted',
        type: 'leadStatus',
        color: '#4CAF50',
        order: 2,
      ),
      LeadStatus(
        name: 'Follow Up',
        type: 'leadStatus',
        color: '#FF9800',
        order: 3,
      ),
      LeadStatus(
        name: 'Qualified',
        type: 'leadStatus',
        color: '#9C27B0',
        order: 4,
      ),
      LeadStatus(
        name: 'Not Interested',
        type: 'leadStatus',
        color: '#F44336',
        order: 5,
      ),
      LeadStatus(
        name: 'Converted',
        type: 'leadStatus',
        color: '#4CAF50',
        order: 6,
      ),
    ];

    // Call status options
    final callStatusOptions = [
      LeadStatus(
        name: 'Not Called',
        type: 'callStatus',
        color: '#757575',
        order: 1,
      ),
      LeadStatus(
        name: 'Called',
        type: 'callStatus',
        color: '#4CAF50',
        order: 2,
      ),
      LeadStatus(
        name: 'Missed',
        type: 'callStatus',
        color: '#F44336',
        order: 3,
      ),
      LeadStatus(
        name: 'Scheduled',
        type: 'callStatus',
        color: '#2196F3',
        order: 4,
      ),
      LeadStatus(name: 'Busy', type: 'callStatus', color: '#FF9800', order: 5),
    ];

    // Save status options
    for (final option in [...leadStatusOptions, ...callStatusOptions]) {
      await _leadRepo.saveStatusOption(option);
    }

    print(
      '[DataSeeding] Created ${leadStatusOptions.length + callStatusOptions.length} status options',
    );
  }

  /// Create sample leads
  static Future<void> _createSampleLeads() async {
    final sampleLeads = [
      Lead(
        firstName: 'John',
        lastName: 'Smith',
        phoneNumber: '+1-555-0123',
        email: 'john.smith@email.com',
        company: 'Tech Solutions Inc.',
        status: 'New',
        remark: 'Interested in our premium package. Follow up next week.',
        callStatus: 'Not Called',
        assignedTo: 'Sales Team',
        source: 'Website',
        priority: 2,
      ),
      Lead(
        firstName: 'Sarah',
        lastName: 'Johnson',
        phoneNumber: '+1-555-0124',
        email: 'sarah.j@company.com',
        company: 'Marketing Pro',
        status: 'Contacted',
        remark: 'Had a great conversation. Very interested in our services.',
        callStatus: 'Called',
        assignedTo: 'Sales Team',
        source: 'Referral',
        priority: 3,
        lastContactedAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
      Lead(
        firstName: 'Mike',
        lastName: 'Wilson',
        phoneNumber: '+1-555-0125',
        email: 'mike.wilson@business.com',
        company: 'Wilson Enterprises',
        status: 'Follow Up',
        remark: 'Needs more information about pricing. Call back in 3 days.',
        callStatus: 'Scheduled',
        assignedTo: 'Sales Team',
        source: 'Cold Call',
        priority: 2,
        lastContactedAt: DateTime.now().subtract(const Duration(days: 5)),
      ),
      Lead(
        firstName: 'Emily',
        lastName: 'Davis',
        phoneNumber: '+1-555-0126',
        email: 'emily.davis@startup.io',
        company: 'StartupCo',
        status: 'Qualified',
        remark: 'Budget approved. Ready to move forward with implementation.',
        callStatus: 'Called',
        assignedTo: 'Sales Team',
        source: 'Trade Show',
        priority: 3,
        lastContactedAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
      Lead(
        firstName: 'Robert',
        lastName: 'Brown',
        phoneNumber: '+1-555-0127',
        email: 'robert.brown@corp.com',
        company: 'Brown Corp',
        status: 'Not Interested',
        remark: 'Not interested at this time. May revisit in 6 months.',
        callStatus: 'Called',
        assignedTo: 'Sales Team',
        source: 'Website',
        priority: 1,
        lastContactedAt: DateTime.now().subtract(const Duration(days: 3)),
      ),
      Lead(
        firstName: 'Lisa',
        lastName: 'Anderson',
        phoneNumber: '+1-555-0128',
        email: 'lisa.anderson@tech.com',
        company: 'Tech Innovations',
        status: 'Converted',
        remark:
            'Successfully converted to customer. Implementation in progress.',
        callStatus: 'Called',
        assignedTo: 'Sales Team',
        source: 'Referral',
        priority: 3,
        lastContactedAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
      Lead(
        firstName: 'David',
        lastName: 'Miller',
        phoneNumber: '+1-555-0129',
        email: 'david.miller@enterprise.com',
        company: 'Enterprise Solutions',
        status: 'New',
        remark: 'Large enterprise client. High potential value.',
        callStatus: 'Not Called',
        assignedTo: 'Enterprise Team',
        source: 'Website',
        priority: 3,
      ),
      Lead(
        firstName: 'Jennifer',
        lastName: 'Taylor',
        phoneNumber: '+1-555-0130',
        email: 'jennifer.taylor@smallbiz.com',
        company: 'Small Business Co',
        status: 'Follow Up',
        remark:
            'Small business owner. Price sensitive. Follow up with special offer.',
        callStatus: 'Missed',
        assignedTo: 'Sales Team',
        source: 'Cold Call',
        priority: 1,
        lastContactedAt: DateTime.now().subtract(const Duration(days: 7)),
      ),
      Lead(
        firstName: 'Piyush',
        lastName: 'Jaiswal',
        phoneNumber: '+91 7499582803',
        email: 'piyush.jaiswal@consulting.com',
        company: 'Jaiswal Consulting',
        status: 'Contacted',
        remark: 'Consultant looking for tools for his clients.',
        callStatus: 'Called',
        assignedTo: 'Sales Team',
        source: 'Referral',
        priority: 2,
        lastContactedAt: DateTime.now().subtract(const Duration(days: 4)),
      ),
      Lead(
        firstName: 'Amanda',
        lastName: 'White',
        phoneNumber: '+1-555-0132',
        email: 'amanda.white@nonprofit.org',
        company: 'Non-Profit Organization',
        status: 'New',
        remark: 'Non-profit organization. May qualify for special pricing.',
        callStatus: 'Not Called',
        assignedTo: 'Sales Team',
        source: 'Website',
        priority: 2,
      ),
    ];

    // Save sample leads
    for (final lead in sampleLeads) {
      await _leadRepo.saveLead(lead);
    }

    print('[DataSeeding] Created ${sampleLeads.length} sample leads');
  }

  /// Clear all sample data
  static Future<void> clearSampleData() async {
    try {
      await _leadRepo.clearAllData();
      print('[DataSeeding] Sample data cleared');
    } catch (e) {
      print('[DataSeeding] Error clearing sample data: $e');
    }
  }

  /// Check if sample data exists
  static bool hasSampleData() {
    final leads = _leadRepo.getAllLeads();
    final statusOptions = _leadRepo.getAllStatusOptions();
    return leads.isNotEmpty || statusOptions.isNotEmpty;
  }
}
