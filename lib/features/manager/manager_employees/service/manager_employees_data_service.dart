import 'package:mobo_employees/features/manager/manager_employees/model/model_fetch_manager_employee_details.dart';
import 'package:mobo_employees/core/services/connectivity_service.dart';
import 'package:mobo_employees/core/services/odoo_session_manager.dart';

class ManagerEmployeesDataService {
  ///fetch all employees from odoo
  static Future<ModelManagerEmployeesResponse> fetchAllEmployees({
    required String search,
    required List<dynamic> domain,
    required int offset,
    required int limit,
  }) async {
    try {
      final odooClient = await OdooSessionManager.callKwWithCompany;
      final majorVersion = await OdooSessionManager.getServerMajorVersion();

      if (search.trim().isNotEmpty) {
        domain.addAll([
          '|',
          ['work_email', 'ilike', search],
          ['name', 'ilike', search],
        ]);
      }

      ///Fetch paginated data
      final records = await odooClient({
        'model': 'hr.employee',
        'method': 'search_read',
        'args': [],
        'kwargs': {
          'domain': domain,
          'offset': offset,
          'limit': limit,
          'fields': [
            'id',
            'name',
            'display_name',
            'active',
            'work_phone',
            'work_email',

            /// Odoo 20 replaced employee_type with employee_type_id
            if (majorVersion < 20) 'employee_type',
            'job_id',
            'department_id',
            'company_id',
            'work_location_id',
            'avatar_128',
            'is_absent',
            'hr_presence_state',
          ],
        },
      });

      final rawCount = await odooClient({
        'model': 'hr.employee',
        'method': 'search_count',
        'args': [domain],
      });

      final int safeTotalCount = rawCount is num ? rawCount.toInt() : 0;

      return ModelManagerEmployeesResponse(
        employees: List<Map<String, dynamic>>.from(
          records,
        ).map(ModelFetchManagerEmployeeDetails.fromJson).toList(),
        totalCount: safeTotalCount,
      );
    } catch (e) {
      if (ConnectivityService.isConnectivityError(e)) rethrow;
      throw Exception("Failed to fetch employees: $e");
    }
  }

  ///fetch employees count from odoo

  static Future<int> fetchAllEmployeesCount({
    required List<dynamic> domain,
    required String search,
  }) async {
    try {
      final odooClient = await OdooSessionManager.callKwWithCompany;

      if (search.trim().isNotEmpty) {
        domain.addAll([
          '|',
          ['work_email', 'ilike', search],
          ['name', 'ilike', search],
        ]);
      }

      final count = await odooClient({
        'model': 'hr.employee',
        'method': 'search_count',
        'args': [domain],
        'kwargs': {},
      });
      return count as int;
    } catch (e) {
      if (ConnectivityService.isConnectivityError(e)) rethrow;
      throw Exception("Failed to fetch employees: $e");
    }
  }
}
