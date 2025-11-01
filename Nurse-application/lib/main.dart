import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nurse_tracking_app/pages/splash_page.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'providers/theme_provider.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

/// 🔹 Background message handler (must be top-level or static)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('📩 Handling a background message: ${message.messageId}');

  await localNotifs.show(
    message.hashCode,
    message.notification?.title ?? 'Background Message',
    message.notification?.body ?? 'You have a new message',
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'high_importance_channel',
        'High Importance Notifications',
        importance: Importance.max,
        priority: Priority.high,
      ),
    ),
  );
}

/// 🔹 Global Supabase client
final supabase = Supabase.instance.client;

/// 🔹 Global notifications plugin
final FlutterLocalNotificationsPlugin localNotifs =
    FlutterLocalNotificationsPlugin();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // ✅ Initialize Firebase first
    await Firebase.initializeApp();

    // ✅ Register background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // ✅ Initialize Supabase
    await Supabase.initialize(
      url: 'https://asbfhxdomvclwsrekdxi.supabase.co',
      anonKey:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFzYmZoeGRvbXZjbHdzcmVrZHhpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTQzMjI3OTUsImV4cCI6MjA2OTg5ODc5NX0.0VzbWIc-uxIDhI03g04n8HSPRQ_p01UTJQ1sg8ggigU',
    );

    // Health check before running app
    final supabase = Supabase.instance.client;
    final test = await supabase.from('employee').select('email').limit(1);
    print('🩺 Supabase health check → Found employees: $test');

    // ✅ Initialize local notifications
    await initLocalNotifs();

    // ✅ Request FCM permissions & log token
    await requestPermissionAndGetToken();

    // ✅ Foreground notifications listener
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('🔥 Foreground message: ${message.data}');

      if (message.notification != null) {
        localNotifs.show(
          message.hashCode,
          message.notification?.title ?? 'Foreground Message',
          message.notification?.body ?? 'You have a new message',
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'high_importance_channel',
              'High Importance Notifications',
              importance: Importance.max,
              priority: Priority.high,
            ),
          ),
        );
      }
    });

    // ✅ Handle notification when tapped from background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('📲 Notification tapped: ${message.data}');
      // 👉 You can navigate to a specific page here if needed
    });

    runApp(
      ChangeNotifierProvider(
        create: (_) => ThemeProvider(),
        child: const MyApp(),
      ),
    );
  } catch (e, st) {
    debugPrint("❌ Initialization error: $e\n$st");
  }
}

/// 🔹 Local notifications setup
Future<void> initLocalNotifs() async {
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosInit = DarwinInitializationSettings();

  await localNotifs.initialize(
    const InitializationSettings(android: androidInit, iOS: iosInit),
    onDidReceiveNotificationResponse: (resp) async {
      await Geolocator.openLocationSettings();
    },
  );

  // Request runtime permissions
  await localNotifs
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.requestNotificationsPermission();

  await localNotifs
      .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>()
      ?.requestPermissions(alert: true, badge: true, sound: true);
}

/// 🔹 Request notification permission & print FCM token
Future<void> requestPermissionAndGetToken() async {
  FirebaseMessaging messaging = FirebaseMessaging.instance;

  NotificationSettings settings = await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  if (settings.authorizationStatus == AuthorizationStatus.authorized) {
    String? token = await messaging.getToken();
    debugPrint('✅ FCM Token: $token');
  } else {
    debugPrint('❌ User declined notifications');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return MaterialApp(
      title: 'Nurse Tracking App',
      debugShowCheckedModeBanner: false,
      theme: themeProvider.lightTheme,
      darkTheme: themeProvider.darkTheme,
      themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: const SplashPage(),
    );
  }
}

extension ContextExtension on BuildContext {
  void showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? Theme.of(this).colorScheme.error
            : Theme.of(this).colorScheme.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
