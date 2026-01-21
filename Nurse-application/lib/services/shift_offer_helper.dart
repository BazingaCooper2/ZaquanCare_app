import 'package:flutter/material.dart';
import '../services/shift_offer_manager.dart'; // Contains SocketConnectionState
import '../services/session.dart';
import '../main.dart' show navigatorKey;

/// Global shift offer manager instance
ShiftOfferManager? _globalShiftOfferManager;

/// Configuration for shift offer system
class ShiftOfferConfig {
  /// WebSocket URL
  /// Note: For Android Emulator use 'ws://10.0.2.2:3000/ws'
  /// Note: For Physical Device use your computer's IP 'ws://192.168.x.x:3000/ws'
  static const String wsUrl = 'ws://localhost:3000/ws';

  /// API Base URL
  /// Note: For Android Emulator use 'http://10.0.2.2:3000/api'
  static const String apiUrl = 'http://localhost:3000/api';
}

/// Initialize shift offer system after login
Future<void> initializeShiftOfferSystem() async {
  try {
    final empId = await SessionManager.getEmpId();
    if (empId == null) {
      debugPrint('⚠️ Cannot initialize shift offers: No employee ID');
      return;
    }

    // Dispose existing manager if any
    if (_globalShiftOfferManager != null) {
      debugPrint('🔄 Disposing existing shift offer manager');
      _globalShiftOfferManager!.dispose();
    }

    // Create new manager
    _globalShiftOfferManager = ShiftOfferManager(
      empId: empId,
      wsUrl: ShiftOfferConfig.wsUrl,
      apiUrl: ShiftOfferConfig.apiUrl,
      navigatorKey: navigatorKey,
    );

    // Initialize
    await _globalShiftOfferManager!.initialize();

    debugPrint('✅ Shift offer system initialized for employee $empId');
  } catch (e) {
    debugPrint('❌ Error initializing shift offer system: $e');
  }
}

/// Dispose shift offer system on logout
void disposeShiftOfferSystem() {
  if (_globalShiftOfferManager != null) {
    debugPrint('🗑️ Disposing shift offer system');
    _globalShiftOfferManager!.dispose();
    _globalShiftOfferManager = null;
  }
}

/// Get the current shift offer manager (if initialized)
ShiftOfferManager? getShiftOfferManager() {
  return _globalShiftOfferManager;
}

/// Check if shift offer system is connected
bool isShiftOfferSystemConnected() {
  return _globalShiftOfferManager?.connectionState ==
      SocketConnectionState.connected;
}

/// Manually refresh pending offers
Future<void> refreshPendingOffers() async {
  if (_globalShiftOfferManager != null) {
    await _globalShiftOfferManager!.refreshPendingOffers();
  } else {
    debugPrint('⚠️ Shift offer manager not initialized');
  }
}
