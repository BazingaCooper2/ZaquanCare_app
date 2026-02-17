import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// import 'package:geolocator/geolocator.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'providers/theme_provider.dart';
import 'pages/splash_page.dart';
import 'widgets/custom_loading_screen.dart';

/// ✅ Global Supabase client
late final SupabaseClient supabase;

/// ✅ Global notifications plugin
final FlutterLocalNotificationsPlugin localNotifs =
    FlutterLocalNotificationsPlugin();

/// ✅ Top-level FCM background message handler (required by Firebase)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('📩 Handling background message: ${message.messageId}');

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

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AppRoot());
}

class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  bool _isInitialized = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    try {
      // ✅ Initialize Firebase first
      await Firebase.initializeApp();

      // ✅ Register background handler
      FirebaseMessaging.onBackgroundMessage(
          _firebaseMessagingBackgroundHandler);

      // ✅ Initialize Supabase
      await Supabase.initialize(
        url: 'https://asbfhxdomvclwsrekdxi.supabase.co',
        anonKey:
            'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFzYmZoeGRvbXZjbHdzcmVrZHhpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTQzMjI3OTUsImV4cCI6MjA2OTg5ODc5NX0.0VzbWIc-uxIDhI03g04n8HSPRQ_p01UTJQ1sg8ggigU',
      );

      supabase = Supabase.instance.client;

      // ✅ Health check (optional)
      try {
        await supabase.from('employee').select('email').limit(1);
        debugPrint('🩺 Supabase OK');
      } catch (e) {
        debugPrint('⚠️ Supabase health check failed (non-critical): $e');
      }

      // ✅ Initialize notifications
      try {
        await _initLocalNotifs();
      } catch (e) {
        debugPrint('⚠️ Local notifications init failed: $e');
      }

      try {
        await _requestPermissionAndGetToken();
      } catch (e) {
        debugPrint('⚠️ FCM token request failed: $e');
      }

      // ✅ Foreground ID notifications listener
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

      // ✅ Handle tap on background notification
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('📲 Notification tapped: ${message.data}');
      });

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e, st) {
      debugPrint("❌ Critical initialization error: $e\n$st");
      if (mounted) {
        setState(() {
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 60, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text(
                    'Initialization Error',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(_error!, textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (!_isInitialized) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: CustomLoadingScreen(
          message: 'Starting ZaqenCare...',
        ),
      );
    }

    return ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const MyApp(),
    );
  }
}

/// ✅ Local notifications setup
Future<void> _initLocalNotifs() async {
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosInit = DarwinInitializationSettings();

  await localNotifs.initialize(
    const InitializationSettings(android: androidInit, iOS: iosInit),
    onDidReceiveNotificationResponse: (resp) async {
      debugPrint('🔔 Local Notification tapped: ${resp.payload}');
      // Handle navigation if needed, e.g. based on payload (offersId)
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

  // Create the notification channel (Android) to ensure sound/pop-up
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'shift_offers_channel', // id
    'Shift Offers', // title
    description: 'Notifications for new shift offers',
    importance: Importance.max, // Importance.max leads to heads-up notification
    playSound: true,
  );

  await localNotifs
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);
}

/// ✅ Request notification permission & get FCM token
Future<void> _requestPermissionAndGetToken() async {
  FirebaseMessaging messaging = FirebaseMessaging.instance;
  NotificationSettings settings = await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  if (settings.authorizationStatus == AuthorizationStatus.authorized) {
    final token = await messaging.getToken();
    debugPrint('✅ FCM Token: $token');
  } else {
    debugPrint('⚠️ User declined notifications');
  }
}

/// ✅ Global navigator key for navigation from services
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return MaterialApp(
      navigatorKey: navigatorKey, // ✅ Add navigator key
      title: 'ZaqenCare',
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
