import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_employees/features/manager/manager_employees/provider/manager_employees_provider.dart';
import 'fake_manager_employees_provider.dart';

void main() {
  group("Manager Employees Page Unit Test", () {
    final provider = FakeManagerEmployeesProvider();
    test("Initial Employees Details", () {
      expect(provider.employees.length, 4);
      expect(provider.employees.first.name, "Name1");
      expect(provider.employees.first.active, true);
    });

    test("Fetch Employees Function", () {
      expect(provider.isLoading, false);
      provider.fetchEmployees();
      expect(provider.isLoading, true);
    });

    test("Search Employee", () {
      provider.updateSearch("Name1");
      final result = provider.employees
          .where((e) => e.name!.toLowerCase().contains("name1"))
          .toList();
      expect(result.length, 1);
      expect(result.first.name, "Name1");

      provider.updateSearch("Name");
      final lengthResult = provider.employees
          .where((e) => e.name.toLowerCase().contains('name'))
          .toList();

      expect(lengthResult.length, 4);
    });

    test("Clear Search", () {
      provider.searchEmployeeController.text = "Abcdef";
      provider.clearSearch();
      expect(provider.searchEmployeeController.text, "");
    });

    test("Toggle Filter in Employees Filter", () {
      provider.toggleDraftFilter(EmployeeFilter.absent);
      expect(provider.draftFilters.contains(EmployeeFilter.absent), true);
      provider.toggleDraftFilter(EmployeeFilter.atWork);
      expect(provider.draftFilters.contains(EmployeeFilter.atWork), true);
      provider.toggleDraftFilter(EmployeeFilter.myTeam);
      expect(provider.draftFilters.contains(EmployeeFilter.myTeam), true);

      provider.toggleDraftFilter(EmployeeFilter.absent);
      expect(provider.draftFilters.contains(EmployeeFilter.absent), false);
      provider.toggleDraftFilter(EmployeeFilter.atWork);
      expect(provider.draftFilters.contains(EmployeeFilter.atWork), false);

      provider.toggleDraftFilter(EmployeeFilter.myTeam);
      expect(provider.draftFilters.contains(EmployeeFilter.myTeam), false);
    });

    test("Apply filter", () {
      provider.draftFilters.add(EmployeeFilter.absent);
      provider.applyDraftFilters();
      final activeFilters = provider.activeFilters.contains(
        EmployeeFilter.absent,
      );
      expect(activeFilters, true);
      final count = provider.draftFilters.length;
      expect(count, 1);
    });

    test("Clear Filters", () {
      provider.clearAllFilters();
      provider.draftFilters.add(EmployeeFilter.myDepartment);
      expect(provider.activeFilters.length, 0);
      expect(provider.draftFilters.length, 1);
      provider.applyDraftFilters();
      expect(provider.activeFilters.length, 1);
      expect(provider.draftFilters.length, 1);
      provider.clearAllFilters();
      expect(provider.activeFilters.length, 0);
      expect(provider.draftFilters.length, 0);
    });

    test("Filter Label when Empty and Active", () {
      provider.activeFilters.clear();
      expect(provider.filterLabel, "No filters applied");
      provider.draftFilters.add(EmployeeFilter.myDepartment);
      provider.applyDraftFilters();
      final count = provider.activeFilters.length;
      expect(provider.filterLabel, "$count Active filters");
    });

    test("Pagination next & Prev", () {
      provider.totalRecords = 41;
      expect(provider.currentPage, 1);
      provider.nextPage();
      expect(provider.currentPage, 2);
      provider.previousPage();
      expect(provider.currentPage, 1);
    });

    test("Can Go next or Back", () {
      provider.totalRecords = 100;
      expect(provider.canGoNext, true);
      expect(provider.canGoPrevious, false);

      provider.currentPage = 2;
      expect(provider.canGoNext, true);
      expect(provider.canGoPrevious, true);

      provider.currentPage = 3;
      expect(provider.canGoNext, false);
      expect(provider.canGoPrevious, true);
    });

    test("Refresh Employees", () async {
      await provider.refreshEmployees();
      expect(provider.isLoading, true);
    });

    test("Prepare Draft Filters", () {
      provider.activeFilters.add(EmployeeFilter.absent);
      provider.prepareDraftFilters();
      expect(provider.draftFilters.contains(EmployeeFilter.absent), true);
    });

    test("Clear On Manager Logout", () {
      provider.searchEmployeeController.text = "abcdef";
      provider.activeFilters.add(EmployeeFilter.atWork);
      provider.employees.clear();
      provider.totalRecords = 50;

      provider.clearOnManagerLogout();

      expect(provider.searchEmployeeController.text, "");
      expect(provider.activeFilters.isEmpty, true);
      expect(provider.draftFilters.isEmpty, true);
      expect(provider.currentPage, 1);
      expect(provider.totalRecords, 0);
    });
  });
}
