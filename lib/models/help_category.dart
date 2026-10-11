import 'package:flutter/material.dart';

/// Concern types in Help & complaints. Each maps to a category of the web
/// Help & Complaint Desk (HelpRequest::CATEGORIES), so staff can sort it.
enum HelpCategory {
  discountProblem,
  seniorIdConcern,
  delayedAssistance,
  pensionConcern,
  applicationConcern,
  documentConcern,
  registrationConcern,
  accountConcern,
  generalInquiry,
  other,
}

extension HelpCategoryInfo on HelpCategory {
  String get label => switch (this) {
        HelpCategory.discountProblem => 'Discount problem',
        HelpCategory.seniorIdConcern => 'Senior ID',
        HelpCategory.delayedAssistance => 'Delayed assistance',
        HelpCategory.pensionConcern => 'Pension',
        HelpCategory.applicationConcern => 'Application',
        HelpCategory.documentConcern => 'Documents',
        HelpCategory.registrationConcern => 'Registration',
        HelpCategory.accountConcern => 'Account or login',
        HelpCategory.generalInquiry => 'General question',
        HelpCategory.other => 'Something else',
      };

  /// One line under the title in the concern list.
  String get hint => switch (this) {
        HelpCategory.discountProblem => 'A store refused your 20% discount',
        HelpCategory.seniorIdConcern => 'Lost, damaged or wrong details',
        HelpCategory.delayedAssistance => 'Promised help has not come yet',
        HelpCategory.pensionConcern => 'Late payment or wrong amount',
        HelpCategory.applicationConcern => 'Question about your application',
        HelpCategory.documentConcern => 'Problem with papers you sent',
        HelpCategory.registrationConcern => 'Problem with your senior record',
        HelpCategory.accountConcern => 'Cannot sign in or use the app',
        HelpCategory.generalInquiry => 'Ask the OSCA office anything',
        HelpCategory.other => 'Anything not on this list',
      };

  IconData get icon => switch (this) {
        HelpCategory.discountProblem => Icons.storefront_outlined,
        HelpCategory.seniorIdConcern => Icons.badge_outlined,
        HelpCategory.delayedAssistance => Icons.hourglass_bottom,
        HelpCategory.pensionConcern => Icons.payments_outlined,
        HelpCategory.applicationConcern => Icons.assignment_outlined,
        HelpCategory.documentConcern => Icons.description_outlined,
        HelpCategory.registrationConcern => Icons.how_to_reg_outlined,
        HelpCategory.accountConcern => Icons.lock_person_outlined,
        HelpCategory.generalInquiry => Icons.help_outline,
        HelpCategory.other => Icons.more_horiz,
      };

  /// Example for the "Short title" box.
  String get titleExample => switch (this) {
        HelpCategory.discountProblem => 'e.g. Pharmacy did not give my discount',
        HelpCategory.seniorIdConcern => 'e.g. I lost my Senior ID',
        HelpCategory.delayedAssistance => 'e.g. Medical help not yet received',
        HelpCategory.pensionConcern => 'e.g. My pension for July is late',
        HelpCategory.applicationConcern => 'e.g. When will my application be checked?',
        HelpCategory.documentConcern => 'e.g. My barangay certificate was rejected',
        HelpCategory.registrationConcern => 'e.g. My birthday is wrong on my record',
        HelpCategory.accountConcern => 'e.g. I cannot log in',
        HelpCategory.generalInquiry => 'e.g. Where do I get my booklet?',
        HelpCategory.other => 'e.g. A short summary of your concern',
      };
  /// The web Help Desk category this is filed under.
  String get deskCategory {
    switch (this) {
      case HelpCategory.discountProblem:
        return 'Program concern';
      case HelpCategory.seniorIdConcern:
        return 'Lost or damaged OSCA ID';
      case HelpCategory.delayedAssistance:
      case HelpCategory.pensionConcern:
        return 'Delayed pension/assistance';
      case HelpCategory.applicationConcern:
      case HelpCategory.registrationConcern:
        return 'Registration concern';
      case HelpCategory.documentConcern:
        return 'Document concern';
      case HelpCategory.accountConcern:
        return 'Account/login concern';
      case HelpCategory.generalInquiry:
        return 'General inquiry';
      case HelpCategory.other:
        return 'Other';
    }
  }

  static HelpCategory? parse(String? name) {
    for (final c in HelpCategory.values) {
      if (c.name == name) return c;
    }
    return null;
  }
}
