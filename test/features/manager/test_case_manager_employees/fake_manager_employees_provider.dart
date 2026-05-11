import 'package:mobo_employees/features/manager/manager_employees/model/model_fetch_manager_employee_details.dart';
import 'package:mobo_employees/features/manager/manager_employees/provider/manager_employees_provider.dart';

class FakeManagerEmployeesProvider extends ManagerEmployeesProvider {
  bool isLoading = false;
  FakeManagerEmployeesProvider() {
    employees = [
      ModelFetchManagerEmployeeDetails(id: 001, name: "Name1", active: true),
      ModelFetchManagerEmployeeDetails(id: 002, name: "Name2", active: true),
      ModelFetchManagerEmployeeDetails(id: 003, name: "Name3", active: false),
      ModelFetchManagerEmployeeDetails(id: 004, name: "Name4", active: true),
    ];
    totalRecords = 4;
  }

  @override
  Future<void> fetchEmployees({bool reset = false, String search = ''}) async {
    isLoading = true;
    notifyListeners();
  }
}
