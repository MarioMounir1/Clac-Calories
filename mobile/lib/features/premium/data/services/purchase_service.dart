// lib/features/premium/data/services/purchase_service.dart
// Aura — RevenueCat Integration Service Singleton

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import '../../../../core/network/api_client.dart';
import '../../../profile/presentation/bloc/profile_bloc.dart';
import '../../../profile/presentation/bloc/profile_event.dart';
import '../../presentation/premium_upgrade_screen.dart';

class PurchaseService {
  PurchaseService._();
  static final PurchaseService instance = PurchaseService._();

  static const bool isTestMode = true; // Set to true for mock purchases during testing, false for production

  // API Keys loaded via String.fromEnvironment (or falling back to the test credentials)
  static const _googleApiKey = String.fromEnvironment('REVENUECAT_GOOGLE_KEY', defaultValue: 'test_WduHLUbxvLMORiUZWfuZsXzkcpV');
  static const _appleApiKey  = String.fromEnvironment('REVENUECAT_APPLE_KEY', defaultValue: 'test_WduHLUbxvLMORiUZWfuZsXzkcpV');

  final _premiumStreamController = StreamController<bool>.broadcast();

  /// Stream to listen to real-time subscription status changes (isPremium)
  Stream<bool> get premiumStream => _premiumStreamController.stream;

  /// Initialize the SDK with the correct platform key
  Future<void> init({String? appUserId}) async {
    try {
      await Purchases.setLogLevel(LogLevel.debug);
      
      if (!Platform.isAndroid && !Platform.isIOS) {
        return; // Platform not supported by RevenueCat
      }

      final configuration = PurchasesConfiguration(
        Platform.isAndroid ? _googleApiKey : _appleApiKey,
      )..appUserID = appUserId;

      await Purchases.configure(configuration);

      if (isTestMode) {
        // Do not listen to real entitlements or emit them in test mode
        _premiumStreamController.add(false);
        return;
      }

      // Listen for subscription updates in real-time
      Purchases.addCustomerInfoUpdateListener((customerInfo) {
        final isActive = customerInfo.entitlements.all['premium']?.isActive ?? false;
        _premiumStreamController.add(isActive);
      });

      // Emit initial entitlement state
      final currentInfo = await Purchases.getCustomerInfo();
      _premiumStreamController.add(currentInfo.entitlements.all['premium']?.isActive ?? false);
    } catch (e) {
      print('❌ [RevenueCat] Initialization error: $e');
    }
  }

  /// Log in the user to sync entitlements across devices
  Future<void> logIn(String appUserId) async {
    if (isTestMode) {
      return; // Do not fetch or emit real customer info in test mode
    }
    try {
      await Purchases.logIn(appUserId);
      final currentInfo = await Purchases.getCustomerInfo();
      _premiumStreamController.add(currentInfo.entitlements.all['premium']?.isActive ?? false);
    } catch (e) {
      print('❌ [RevenueCat] LogIn error: $e');
    }
  }

  /// Check current entitlement status synchronously/on-demand
  Future<bool> isPremium() async {
    if (isTestMode) {
      return false; // Let database status control it in test mode
    }
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      return customerInfo.entitlements.all['premium']?.isActive ?? false;
    } catch (e) {
      print('❌ [RevenueCat] check error: $e');
      return false;
    }
  }

  /// Fetch all available subscription packages/offerings
  Future<Offerings> fetchOfferings() async {
    try {
      return await Purchases.getOfferings();
    } catch (e) {
      print('❌ [RevenueCat] fetchOfferings error: $e');
      rethrow;
    }
  }

  /// Purchase a package and return the updated premium entitlement status
  Future<bool> purchaseSubPackage(Package package) async {
    if (isTestMode) {
      print('ℹ️ [PurchaseService] simulating local 1-second purchase in Test Mode...');
      await Future.delayed(const Duration(seconds: 1));
      print('✅ Successful \$1.00 test purchase logged!');
      return true;
    }

    try {
      final purchaseResult = await Purchases.purchasePackage(package);
      final isNowPremium = purchaseResult.customerInfo.entitlements.all['premium']?.isActive ?? false;
      return isNowPremium;
    } catch (e) {
      print('❌ [RevenueCat] purchase error: $e');
      rethrow;
    }
  }

  /// Purchase a package (alias to match verification requirements)
  Future<bool> purchasePackage(Package package) => purchaseSubPackage(package);

  /// Restore purchases (useful for Apple App Store/Google Play Store reviews)
  Future<bool> restorePurchases() async {
    try {
      final customerInfo = await Purchases.restorePurchases();
      final isNowPremium = customerInfo.entitlements.all['premium']?.isActive ?? false;
      _premiumStreamController.add(isNowPremium);
      return isNowPremium;
    } catch (e) {
      print('❌ [RevenueCat] restore error: $e');
      rethrow;
    }
  }

  /// Present the custom Flutter Paywall Screen.
  /// If the purchase is successful, syncs to backend and refreshes profile.
  Future<bool> presentPaywall(BuildContext context) async {
    if (context.mounted) {
      final isNowPremium = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) => const PremiumUpgradeScreen(),
          fullscreenDialog: true,
        ),
      );
      return isNowPremium ?? false;
    }
    return false;
  }

  /// For mock/fallback testing purposes
  void setMockPremiumStatus(bool isPremium) {
    _premiumStreamController.add(isPremium);
  }
}
