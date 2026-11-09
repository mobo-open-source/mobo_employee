import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_employees/features/profile/providers/profile_provider.dart';

void main() {
  group('ProfileProvider.deniedFieldsIn', () {
    test('Odoo 18 lists every denied field in one message', () {
      // Copied from the Configuration screen of a plain employee (the demo
      // user) on an Odoo 18 database.
      const message =
          'You do not have enough rights to access the fields '
          '"private_street,private_street2,private_city,private_zip,'
          'private_state_id,private_country_id" on User (res.users). '
          'Please contact your system administrator.\n\n'
          'Operation: read\nUser: 6\nFields:\n'
          "- private_city (allowed for groups 'Employees / Officer: Manage all employees')";

      expect(ProfileProvider.deniedFieldsIn(message), {
        'private_street',
        'private_street2',
        'private_city',
        'private_zip',
        'private_state_id',
        'private_country_id',
      });
    });

    test('Odoo 18 with a single denied field', () {
      const message =
          'You do not have enough rights to access the fields "job_title" '
          'on User (res.users). Please contact your system administrator.';

      expect(ProfileProvider.deniedFieldsIn(message), {'job_title'});
    });

    test('Odoo 20 names a single field', () {
      const message =
          'You do not have enough rights to access the field "private_street" '
          'on User (res.users). Please contact your system administrator.';

      expect(ProfileProvider.deniedFieldsIn(message), {'private_street'});
    });

    test('an unrelated error names no field', () {
      expect(ProfileProvider.deniedFieldsIn('Connection refused'), isEmpty);
    });
  });
}
