import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/shift_offer_record.dart'; // Updated model
import '../services/shift_offers_service.dart'; // Updated service
import '../widgets/shift_offer_dialog.dart';
import '../main.dart';
import '../pages/shift_offers_page.dart'; // For navigation
import '../models/employee.dart'; // For navigation

enum SocketConnectionState { disconnected, connecting, connected, error }

/// Manages shift offers - coordinates WebSocket, API, and UI
class ShiftOfferManager {
  final int empId;
  final GlobalKey<NavigatorState> navigatorKey;

  RealtimeChannel? _subscription;
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  // Connection state is simplified for Realtime
  SocketConnectionState get connectionState => _subscription != null
      ? SocketConnectionState.connected
      : SocketConnectionState.disconnected;

  ShiftOfferManager({
    required this.empId,
    required this.navigatorKey,
    // wsUrl and apiUrl are no longer needed for Supabase Realtime
    String? wsUrl,
    String? apiUrl,
  });

  /// Initialize and start listening for offers
  Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('⚠️ ShiftOfferManager already initialized');
      return;
    }

    debugPrint('🚀 Initializing ShiftOfferManager for employee $empId');

    try {
      // Subscribe to Supabase Realtime for this employee's offers
      _subscription = supabase
          .channel('public:shift_offers:emp_id=$empId')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'shift_offers',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'emp_id',
              value: empId,
            ),
            callback: (payload) {
              debugPrint('🔔 Realtime INSERT received: ${payload.newRecord}');
              _handleNewOffer(payload.newRecord);
            },
          )
          .subscribe((status, error) {
        if (status == RealtimeSubscribeStatus.subscribed) {
          debugPrint('✅ Subscribed to shift offers for emp $empId');
        } else if (status == RealtimeSubscribeStatus.closed) {
          debugPrint('❌ Subscription closed');
        } else if (error != null) {
          debugPrint('❌ Subscription error: $error');
        }
      });

      // Load any pending offers from server (offline recovery)
      await _loadPendingOffers();

      _isInitialized = true;
      debugPrint('✅ ShiftOfferManager initialized');
    } catch (e) {
      debugPrint('❌ Error initializing ShiftOfferManager: $e');
    }
  }

  /// Handle incoming new offer (from Realtime)
  Future<void> _handleNewOffer(Map<String, dynamic> record) async {
    try {
      final offersId = record['offers_id'] as int;
      debugPrint('📨 Processing new offer ID: $offersId');

      // Fetch full details
      final offer = await ShiftOffersService.fetchOffer(offersId);

      if (offer != null) {
        // Show local notification
        await _showNotification(offer);

        // Show dialog if context available
        final context = navigatorKey.currentContext;
        if (context != null && context.mounted) {
          // Add delay to ensure UI is ready if navigating
          Future.delayed(const Duration(milliseconds: 500), () {
            if (context.mounted) {
              _showRealtimeOfferDialog(context, offer);
            }
          });
        }
      }
    } catch (e) {
      debugPrint('❌ Error handling new offer: $e');
    }
  }

  /// Show local notification for new offer
  Future<void> _showNotification(ShiftOfferRecord offer) async {
    try {
      const androidDetails = AndroidNotificationDetails(
        'shift_offers_channel',
        'Shift Offers',
        channelDescription: 'Notifications for new shift offers',
        importance: Importance.max,
        priority: Priority.high,
        ticker: 'New Shift Offer',
      );

      const details = NotificationDetails(android: androidDetails);

      await localNotifs.show(
        offer.offersId,
        'New Shift Offer Received!',
        'Date: ${offer.shiftDate ?? 'Unknown'} | Time: ${offer.shiftTimeDisplay}',
        details,
      );
    } catch (e) {
      debugPrint('❌ Error showing notification: $e');
    }
  }

  /// Show dialog for realtime offer
  void _showRealtimeOfferDialog(BuildContext context, ShiftOfferRecord offer) {
    showShiftOfferDialog(
      context: context,
      offer: offer,
      onAccepted: () {
        debugPrint('✅ User clicked "View & Accept"');
        // Navigate to ShiftOffersPage for full details and action
        if (context.mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ShiftOffersPage(
                employee: Employee(
                  empId: empId, // Use the manager's empId
                  firstName: '',
                  lastName: '',
                  email: '',
                ),
              ),
            ),
          );
        }
      },
      onRejected: () {
        debugPrint('❌ User dismissed offer dialog');
      },
    );
  }

  /// Load pending offers (offline recovery)
  Future<void> _loadPendingOffers() async {
    try {
      debugPrint('📥 Loading pending offers...');
      final pendingOffers = await ShiftOffersService.fetchPendingOffers(empId);

      if (pendingOffers.isEmpty) return;

      debugPrint('📦 Found ${pendingOffers.length} pending offers');
    } catch (e) {
      debugPrint('❌ Error loading pending offers: $e');
    }
  }

  /// Manually refresh pending offers
  Future<void> refreshPendingOffers() async {
    await _loadPendingOffers();
  }

  /// Disconnect
  Future<void> disconnect() async {
    debugPrint('👋 Disconnecting ShiftOfferManager');
    await _subscription?.unsubscribe();
    _subscription = null;
    _isInitialized = false;
  }

  /// Dispose and clean up
  void dispose() {
    debugPrint('🗑️ Disposing ShiftOfferManager');
    disconnect();
  }
}
