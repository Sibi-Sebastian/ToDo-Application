import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:carousel_slider/carousel_slider.dart';

import 'model/task.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Task Manager',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        textTheme: GoogleFonts.montserratTextTheme(),
      ),
      home: HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  static const routeName = '/home-screen';

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late TextEditingController _taskController;
  late List<Task> _tasks;
  late List<bool> _tasksDone;
  DateTime? _reminderTime;
  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    _taskController = TextEditingController();
    _initializeNotifications();
    _getTasks();
  }

  void _initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('app_icon');
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings();
    const InitializationSettings initializationSettings =
        InitializationSettings(
            android: initializationSettingsAndroid,
            iOS: initializationSettingsIOS);
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
    const MethodChannel platform =
        MethodChannel('dexterx.dev/flutter_local_notifications_example');
    platform.setMethodCallHandler((MethodCall call) async {
      if (call.method == 'onNotificationClicked') {
        _showTaskNotificationDialog(call.arguments as String);
      }
    });
  }

  void saveData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    Task t = Task(task: _taskController.text, reminderTime: _reminderTime!);
    String? tasks = prefs.getString('task');
    List list = (tasks == null) ? [] : json.decode(tasks);
    list.add(json.encode(t.toMap()));
    prefs.setString('task', json.encode(list));
    scheduleNotification(t);
    _taskController.text = '';
    Navigator.of(context).pop();
    _getTasks();
  }

  void _getTasks() async {
    _tasks = [];
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? tasks = prefs.getString('task');
    List list = (tasks == null) ? [] : json.decode(tasks);
    for (dynamic d in list) {
      _tasks.add(Task.fromMap(json.decode(d)));
    }
    _tasksDone = List.generate(_tasks.length, (index) => false);
    setState(() {});
  }

  void updatePendingTasksList() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<Task> pendingList = [];
    for (var i = 0; i < _tasks.length; i++) {
      if (!_tasksDone[i]) pendingList.add(_tasks[i]);
    }
    var pendingListEncoded = List.generate(
        pendingList.length, (i) => json.encode(pendingList[i].toMap()));
    prefs.setString('task', json.encode(pendingListEncoded));
    _getTasks();
  }

  void scheduleNotification(Task task) {
    var scheduledNotificationDateTime =
        tz.TZDateTime.from(task.reminderTime, tz.local);
    var androidPlatformChannelSpecifics = const AndroidNotificationDetails(
        'your channel id', 'your channel name');
    var iOSPlatformChannelSpecifics = const DarwinNotificationDetails();
    NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iOSPlatformChannelSpecifics);

    flutterLocalNotificationsPlugin.zonedSchedule(
      0,
      'Task Reminder',
      task.task,
      scheduledNotificationDateTime,
      platformChannelSpecifics,
      androidAllowWhileIdle: true,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: task.task,
    );
  }

  void _showTaskNotificationDialog(String taskName) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Task Reminder'),
          content: Text(
              'Task Name: $taskName\nTime: ${DateFormat('yyyy-MM-dd – kk:mm').format(DateTime.now())}'),
          actions: <Widget>[
            TextButton(
              child: Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _taskController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    List<Task> completedTasks = [];
    List<Task> incompleteTasks = [];

    for (int i = 0; i < _tasks.length; i++) {
      if (_tasksDone[i]) {
        completedTasks.add(_tasks[i]);
      } else {
        incompleteTasks.add(_tasks[i]);
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Task Manager',
          style: GoogleFonts.montserrat(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: updatePendingTasksList,
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () async {
              SharedPreferences prefs = await SharedPreferences.getInstance();
              prefs.setString('task', json.encode([]));
              _getTasks();
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue[200]!, Colors.blue[400]!],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: CarouselSlider(
          options: CarouselOptions(
            height: double.infinity,
            enlargeCenterPage: true,
            enableInfiniteScroll: false,
          ),
          items: [
            _buildTaskList(incompleteTasks, 'Incomplete Tasks'),
            _buildTaskList(completedTasks, 'Completed Tasks'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(
          Icons.add,
          color: Colors.white,
        ),
        backgroundColor: Colors.blueAccent,
        onPressed: () => showModalBottomSheet(
          context: context,
          builder: (BuildContext context) => _buildBottomSheet(),
        ),
      ),
    );
  }

  Widget _buildTaskList(List<Task> tasks, String title) {
    return Column(
      children: [
        Text(
          title,
          style:
              GoogleFonts.montserrat(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: tasks.length,
            itemBuilder: (context, index) {
              return Card(
                margin:
                    const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                child: ListTile(
                  title: Text(tasks[index].task),
                  subtitle: Text(
                      'Reminder: ${DateFormat('yyyy-MM-dd – kk:mm').format(tasks[index].reminderTime)}'),
                  trailing: Checkbox(
                    value: _tasksDone[_tasks.indexOf(tasks[index])],
                    onChanged: (val) {
                      setState(() {
                        _tasksDone[_tasks.indexOf(tasks[index])] = val!;
                      });
                    },
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBottomSheet() {
    return Container(
      padding: const EdgeInsets.all(10.0),
      height: 350,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Add task',
                style: GoogleFonts.montserrat(
                  color: Colors.black,
                  fontSize: 20.0,
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: const Icon(Icons.close),
              ),
            ],
          ),
          const Divider(thickness: 1.2),
          const SizedBox(height: 20.0),
          TextField(
            controller: _taskController,
            decoration: InputDecoration(
              hintText: 'Enter task name',
              hintStyle: GoogleFonts.montserrat(
                color: Colors.grey,
              ),
            ),
          ),
          const SizedBox(height: 20.0),
          ElevatedButton(
            onPressed: () async {
              final picked = await showDateTimeDialog(
                context,
                initialDate: DateTime.now(),
                dateTime: DateTime.now(),
              );
              if (picked != null) {
                setState(() {
                  _reminderTime = picked;
                });
              }
            },
            child: Text(
              _reminderTime != null
                  ? 'Reminder: ${DateFormat('yyyy-MM-dd – kk:mm').format(_reminderTime!)}'
                  : 'Set Reminder',
            ),
          ),
          const SizedBox(height: 20.0),
          ElevatedButton(
            onPressed: saveData,
            child: Text(
              'Save',
              style: GoogleFonts.montserrat(
                fontSize: 18.0,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<DateTime?> showDateTimeDialog(BuildContext context,
      {required DateTime initialDate, required DateTime dateTime}) {
    return showDialog<DateTime>(
      context: context,
      builder: (BuildContext context) {
        return _DateTimePickerDialog(
          initialDate: initialDate,
          dateTime: dateTime,
        );
      },
    );
  }
}

class _DateTimePickerDialog extends StatefulWidget {
  final DateTime initialDate;
  final DateTime dateTime;

  const _DateTimePickerDialog(
      {Key? key, required this.initialDate, required this.dateTime})
      : super(key: key);

  @override
  _DateTimePickerDialogState createState() => _DateTimePickerDialogState();
}

class _DateTimePickerDialogState extends State<_DateTimePickerDialog> {
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.dateTime;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Select date and time'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ElevatedButton(
            onPressed: () async {
              DateTime? picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime(2000),
                lastDate: DateTime(2101),
              );
              if (picked != null && picked != _selectedDate) {
                setState(() {
                  _selectedDate = DateTime(
                    picked.year,
                    picked.month,
                    picked.day,
                    _selectedDate.hour,
                    _selectedDate.minute,
                  );
                });
              }
            },
            child: Text(DateFormat('yyyy-MM-dd').format(_selectedDate)),
          ),
          ElevatedButton(
            onPressed: () async {
              TimeOfDay? picked = await showTimePicker(
                context: context,
                initialTime: TimeOfDay.fromDateTime(_selectedDate),
              );
              if (picked != null) {
                setState(() {
                  _selectedDate = DateTime(
                    _selectedDate.year,
                    _selectedDate.month,
                    _selectedDate.day,
                    picked.hour,
                    picked.minute,
                  );
                });
              }
            },
            child: Text(DateFormat('HH:mm').format(_selectedDate)),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_selectedDate),
          child: const Text('OK'),
        ),
      ],
    );
  }
}
