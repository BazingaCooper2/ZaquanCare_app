import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  // Initialize Supabase
  await Supabase.initialize(
    url: 'https://asbfhxdomvclwsrekdxi.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFzYmZoeGRvbXZjbHdzcmVrZHhpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTQzMjI3OTUsImV4cCI6MjA2OTg5ODc5NX0.0VzbWIc-uxIDhI03g04n8HSPRQ_p01UTJQ1sg8ggigU',
  );

  final supabase = Supabase.instance.client;

  print('--- DEBUGGING TASKS TABLE ---');

  try {
    // 1. Fetch one row to see schema keys
    final oneRow = await supabase.from('tasks').select().limit(1);
    if (oneRow.isNotEmpty) {
      print('✅ Tasks table schema (first row):');
      print(oneRow.first.keys.toList());
      print('Sample row: ${oneRow.first}');
    } else {
      print('⚠️ Tasks table is empty.');
    }

    // 2. Fetch row with task_code = T010
    print('\nChecking for task_code = "T010"...');
    // Note: Assuming column name is 'task_code' or 'taskId' or 'task_id' (text).
    // We will list all tasks to be sure.
    final allTasks = await supabase.from('tasks').select();
    print('Found ${allTasks.length} total tasks.');

    for (var task in allTasks) {
      print('Task: $task');
    }
  } catch (e) {
    print('❌ Error fetching tasks: $e');
  }
}
