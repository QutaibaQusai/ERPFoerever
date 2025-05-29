// lib/services/contacts_service.dart - WITH TERMINAL CONTACT DISPLAY
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io' show Platform;

class AppContactsService {
  static final AppContactsService _instance = AppContactsService._internal();
  factory AppContactsService() => _instance;
  AppContactsService._internal();

  /// Enhanced iOS diagnostic version with terminal contact display
  Future<Map<String, dynamic>> getAllContacts() async {
    try {
      debugPrint('📱 === iOS CONTACTS DIAGNOSTIC START ===');
      debugPrint('🔍 Platform: ${Platform.operatingSystem}');
      debugPrint('🔍 Platform version: ${Platform.operatingSystemVersion}');

      // STEP 1: Check if contacts are available at all
      debugPrint('📱 Step 1: Checking if contacts service is available...');
      
      // STEP 2: Check current permission status
      PermissionStatus permission = await Permission.contacts.status;
      debugPrint('🔍 Step 2: Current permission status: $permission');
      debugPrint('🔍 Permission details:');
      debugPrint('  - isGranted: ${permission.isGranted}');
      debugPrint('  - isDenied: ${permission.isDenied}');
      debugPrint('  - isPermanentlyDenied: ${permission.isPermanentlyDenied}');
      debugPrint('  - isRestricted: ${permission.isRestricted}');
      debugPrint('  - isLimited: ${permission.isLimited}');

      // STEP 3: For iOS, let's try flutter_contacts permission check
      if (Platform.isIOS) {
        debugPrint('🍎 Step 3: iOS - Checking flutter_contacts permission...');
        try {
          bool flutterContactsPermission = await FlutterContacts.requestPermission();
          debugPrint('🍎 FlutterContacts.requestPermission() result: $flutterContactsPermission');
          
          // Check permission status again after flutter_contacts request
          permission = await Permission.contacts.status;
          debugPrint('🍎 Permission status after flutter_contacts request: $permission');
          
          if (flutterContactsPermission) {
            debugPrint('✅ FlutterContacts says permission granted, trying to get contacts...');
            
            // Try to get contacts using flutter_contacts directly
            List<Contact> contacts = await FlutterContacts.getContacts(
              withProperties: true,
              withThumbnail: false,
              withPhoto: false,
            );
            
            debugPrint('📞 Successfully got ${contacts.length} contacts via FlutterContacts');
            
            // PRINT ALL CONTACTS TO TERMINAL
            _printContactsToTerminal(contacts);
            
            List<Map<String, dynamic>> contactsList = _processContactsForReturn(contacts);
            
            return {
              'success': true,
              'contacts': contactsList,
              'totalCount': contacts.length,
              'method': 'flutter_contacts_direct',
              'permissionStatus': permission.toString(),
            };
          }
        } catch (e) {
          debugPrint('❌ FlutterContacts error: $e');
        }
      }

      // STEP 4: Traditional permission_handler approach
      debugPrint('📱 Step 4: Using permission_handler approach...');
      
      if (permission.isDenied) {
        debugPrint('🔐 Permission denied, requesting permission...');
        permission = await Permission.contacts.request();
        debugPrint('📝 Permission request result: $permission');
      }

      if (permission.isPermanentlyDenied) {
        debugPrint('❌ Permission permanently denied');
        return {
          'success': false,
          'error': 'Contacts permission permanently denied. Please go to Settings > ERPForever > Contacts and enable access.',
          'errorCode': 'PERMISSION_DENIED_FOREVER',
          'contacts': [],
          'permissionStatus': permission.toString(),
          'needsManualSettings': true,
          'settingsPath': 'Settings > ERPForever > Contacts',
          'diagnostic': 'iOS permission permanently denied - user must manually enable in Settings'
        };
      }

      if (permission.isRestricted) {
        debugPrint('🚫 Permission restricted (parental controls or enterprise policy)');
        return {
          'success': false,
          'error': 'Contacts access is restricted by device policy (parental controls or enterprise settings).',
          'errorCode': 'PERMISSION_RESTRICTED',
          'contacts': [],
          'permissionStatus': permission.toString(),
          'diagnostic': 'iOS permission restricted by device policy'
        };
      }

      if (!permission.isGranted) {
        debugPrint('❌ Permission not granted: $permission');
        return {
          'success': false,
          'error': 'Contacts permission required but not granted.',
          'errorCode': 'PERMISSION_NOT_GRANTED',
          'contacts': [],
          'permissionStatus': permission.toString(),
          'diagnostic': 'Permission request failed or denied by user'
        };
      }

      debugPrint('✅ Step 5: Permission granted, fetching contacts...');

      // STEP 5: Get contacts
      List<Contact> contacts = await FlutterContacts.getContacts(
        withProperties: true,
        withThumbnail: false,
        withPhoto: false,
      );

      debugPrint('📞 Successfully retrieved ${contacts.length} contacts');

      // PRINT ALL CONTACTS TO TERMINAL
      _printContactsToTerminal(contacts);

      List<Map<String, dynamic>> contactsList = _processContactsForReturn(contacts);

      debugPrint('📞 === iOS CONTACTS DIAGNOSTIC SUCCESS ===');
      debugPrint('📊 Final Results:');
      debugPrint('  - Total contacts: ${contactsList.length}');
      debugPrint('  - Permission status: $permission');
      debugPrint('  - Method: permission_handler + flutter_contacts');

      return {
        'success': true,
        'contacts': contactsList,
        'totalCount': contactsList.length,
        'permissionStatus': permission.toString(),
        'method': 'permission_handler',
        'diagnostic': 'SUCCESS: Retrieved contacts successfully'
      };

    } catch (e) {
      debugPrint('❌ === iOS CONTACTS DIAGNOSTIC ERROR ===');
      debugPrint('❌ Error: $e');
      debugPrint('❌ Error type: ${e.runtimeType}');
      
      return {
        'success': false,
        'error': 'Failed to get contacts: ${e.toString()}',
        'errorCode': 'UNKNOWN_ERROR',
        'contacts': [],
        'diagnostic': 'EXCEPTION: ${e.toString()}',
        'errorType': e.runtimeType.toString(),
      };
    }
  }

  /// Print all contacts to terminal in a beautiful format
  void _printContactsToTerminal(List<Contact> contacts) {
    debugPrint('');
    debugPrint('📋 ═══════════════════════════════════════════════════════════════');
    debugPrint('📋                     ALL CONTACTS DISPLAY                       ');
    debugPrint('📋 ═══════════════════════════════════════════════════════════════');
    debugPrint('📋 Total Contacts Found: ${contacts.length}');
    debugPrint('📋 ═══════════════════════════════════════════════════════════════');
    debugPrint('');

    if (contacts.isEmpty) {
      debugPrint('📭 No contacts found on this device.');
      debugPrint('');
      return;
    }

    // Sort contacts alphabetically for better display
    contacts.sort((a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));

    for (int i = 0; i < contacts.length; i++) {
      Contact contact = contacts[i];
      
      // Skip empty contacts
      if (contact.displayName.trim().isEmpty) continue;

      debugPrint('👤 Contact #${i + 1}:');
      debugPrint('   ┌─ Name: ${contact.displayName}');
      
      if (contact.name.first.isNotEmpty || contact.name.last.isNotEmpty) {
        debugPrint('   ├─ First: ${contact.name.first}');
        debugPrint('   ├─ Last: ${contact.name.last}');
      }
      
      if (contact.name.middle.isNotEmpty) {
        debugPrint('   ├─ Middle: ${contact.name.middle}');
      }

      if (contact.organizations.isNotEmpty) {
        debugPrint('   ├─ Company: ${contact.organizations.first.company}');
        if (contact.organizations.first.title.isNotEmpty) {
          debugPrint('   ├─ Title: ${contact.organizations.first.title}');
        }
      }

      // Phone numbers
      if (contact.phones.isNotEmpty) {
        debugPrint('   ├─ Phones:');
        for (Phone phone in contact.phones) {
          String label = phone.label.name.toLowerCase();
          debugPrint('   │  ├─ $label: ${phone.number}');
        }
      }

      // Email addresses
      if (contact.emails.isNotEmpty) {
        debugPrint('   ├─ Emails:');
        for (Email email in contact.emails) {
          String label = email.label.name.toLowerCase();
          debugPrint('   │  ├─ $label: ${email.address}');
        }
      }

      // Addresses
      if (contact.addresses.isNotEmpty) {
        debugPrint('   ├─ Addresses:');
        for (Address address in contact.addresses) {
          String label = address.label.name.toLowerCase();
          debugPrint('   │  ├─ $label:');
          if (address.street.isNotEmpty) debugPrint('   │  │  ├─ Street: ${address.street}');
          if (address.city.isNotEmpty) debugPrint('   │  │  ├─ City: ${address.city}');
          if (address.state.isNotEmpty) debugPrint('   │  │  ├─ State: ${address.state}');
          if (address.postalCode.isNotEmpty) debugPrint('   │  │  ├─ ZIP: ${address.postalCode}');
          if (address.country.isNotEmpty) debugPrint('   │  │  └─ Country: ${address.country}');
        }
      }

      // Websites
      if (contact.websites.isNotEmpty) {
        debugPrint('   ├─ Websites:');
        for (Website website in contact.websites) {
          String label = website.label.name.toLowerCase();
          debugPrint('   │  ├─ $label: ${website.url}');
        }
      }

      // Social media
      if (contact.socialMedias.isNotEmpty) {
        debugPrint('   ├─ Social Media:');
        for (SocialMedia social in contact.socialMedias) {
          String label = social.label.name.toLowerCase();
          debugPrint('   │  ├─ $label: ${social.userName}');
        }
      }

      // Events (birthdays, anniversaries)
      if (contact.events.isNotEmpty) {
        debugPrint('   ├─ Events:');
        for (Event event in contact.events) {
          String label = event.label.name.toLowerCase();
          if (event.year != null && event.month != null && event.day != null) {
            debugPrint('   │  ├─ $label: ${event.year}-${event.month.toString().padLeft(2, '0')}-${event.day.toString().padLeft(2, '0')}');
          }
        }
      }

      // Notes
      if (contact.notes.isNotEmpty) {
        for (Note note in contact.notes) {
          if (note.note.isNotEmpty) {
            debugPrint('   ├─ Note: ${note.note}');
          }
        }
      }

      debugPrint('   └─ ID: ${contact.id}');
      debugPrint('');
    }

    debugPrint('📋 ═══════════════════════════════════════════════════════════════');
    debugPrint('📋                    END OF CONTACTS DISPLAY                     ');
    debugPrint('📋 ═══════════════════════════════════════════════════════════════');
    debugPrint('');
  }

  /// Process contacts for return (same as before but extracted)
  List<Map<String, dynamic>> _processContactsForReturn(List<Contact> contacts) {
    List<Map<String, dynamic>> contactsList = [];
    
    for (Contact contact in contacts) {
      if (contact.displayName.trim().isEmpty) continue;

      contactsList.add({
        'id': contact.id,
        'displayName': contact.displayName.trim(),
        'givenName': contact.name.first.trim(),
        'familyName': contact.name.last.trim(),
        'middleName': contact.name.middle.trim(),
        'company': contact.organizations.isNotEmpty
            ? contact.organizations.first.company.trim()
            : '',
        'jobTitle': contact.organizations.isNotEmpty
            ? contact.organizations.first.title.trim()
            : '',
        'phones': contact.phones.map((phone) => ({
          'value': phone.number,
          'label': phone.label.name.toLowerCase(),
        })).toList(),
        'emails': contact.emails.map((email) => ({
          'value': email.address,
          'label': email.label.name.toLowerCase(),
        })).toList(),
        'addresses': contact.addresses.map((address) => ({
          'street': address.street,
          'city': address.city,
          'state': address.state,
          'postalCode': address.postalCode,
          'country': address.country,
          'label': address.label.name.toLowerCase(),
        })).toList(),
        'websites': contact.websites.map((website) => ({
          'url': website.url,
          'label': website.label.name.toLowerCase(),
        })).toList(),
        'notes': contact.notes.map((note) => note.note).where((note) => note.isNotEmpty).toList(),
      });
    }

    contactsList.sort((a, b) => 
      a['displayName'].toString().toLowerCase().compareTo(
        b['displayName'].toString().toLowerCase()
      )
    );

    return contactsList;
  }

  /// Quick method to just print contacts without all the permission logic
  Future<void> printAllContactsToTerminal() async {
    try {
      debugPrint('🔍 Quick print all contacts to terminal...');
      
      List<Contact> contacts = await FlutterContacts.getContacts(
        withProperties: true,
        withThumbnail: false,
        withPhoto: false,
      );
      
      _printContactsToTerminal(contacts);
      
    } catch (e) {
      debugPrint('❌ Error printing contacts: $e');
    }
  }

  /// iOS-specific permission check (unchanged)
  Future<Map<String, dynamic>> checkiOSContactsAccess() async {
    try {
      debugPrint('🍎 === iOS CONTACTS ACCESS CHECK ===');
      
      // Method 1: permission_handler
      PermissionStatus permissionHandlerStatus = await Permission.contacts.status;
      debugPrint('🔍 permission_handler status: $permissionHandlerStatus');
      
      // Method 2: flutter_contacts
      bool flutterContactsAccess = false;
      try {
        flutterContactsAccess = await FlutterContacts.requestPermission();
        debugPrint('🔍 flutter_contacts access: $flutterContactsAccess');
      } catch (e) {
        debugPrint('❌ flutter_contacts error: $e');
      }
      
      return {
        'permission_handler_status': permissionHandlerStatus.toString(),
        'permission_handler_granted': permissionHandlerStatus.isGranted,
        'permission_handler_denied': permissionHandlerStatus.isDenied,
        'permission_handler_permanently_denied': permissionHandlerStatus.isPermanentlyDenied,
        'permission_handler_restricted': permissionHandlerStatus.isRestricted,
        'flutter_contacts_access': flutterContactsAccess,
        'platform': Platform.operatingSystem,
        'platform_version': Platform.operatingSystemVersion,
      };
    } catch (e) {
      return {
        'error': e.toString(),
        'platform': Platform.operatingSystem,
      };
    }
  }

  /// Force permission request with detailed logging (unchanged)
  Future<Map<String, dynamic>> forceRequestPermission() async {
    try {
      debugPrint('🔐 === FORCE REQUEST PERMISSION ===');
      
      // Step 1: Check current status
      PermissionStatus currentStatus = await Permission.contacts.status;
      debugPrint('🔍 Current status before request: $currentStatus');
      
      if (currentStatus.isPermanentlyDenied) {
        debugPrint('⚠️ Status is permanently denied - opening settings');
        bool settingsOpened = await openAppSettings();
        return {
          'success': false,
          'message': 'Permission permanently denied. Settings opened: $settingsOpened',
          'action': 'settings_opened',
          'settings_opened': settingsOpened,
        };
      }
      
      // Step 2: Request permission
      debugPrint('🔐 Requesting permission...');
      PermissionStatus requestResult = await Permission.contacts.request();
      debugPrint('📝 Request result: $requestResult');
      
      // Step 3: Try flutter_contacts method as well
      debugPrint('🔐 Also trying flutter_contacts request...');
      bool flutterResult = await FlutterContacts.requestPermission();
      debugPrint('📝 FlutterContacts result: $flutterResult');
      
      // Step 4: Final status check
      PermissionStatus finalStatus = await Permission.contacts.status;
      debugPrint('🔍 Final status: $finalStatus');
      
      return {
        'success': requestResult.isGranted || flutterResult,
        'permission_handler_result': requestResult.toString(),
        'flutter_contacts_result': flutterResult,
        'final_status': finalStatus.toString(),
        'message': requestResult.isGranted 
            ? 'Permission granted successfully'
            : 'Permission not granted: $requestResult',
      };
      
    } catch (e) {
      debugPrint('❌ Error in force request: $e');
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to request permission',
      };
    }
  }

  /// Open app settings (unchanged)
  Future<bool> openSettings() async {
    try {
      debugPrint('⚙️ Opening app settings...');
      return await openAppSettings();
    } catch (e) {
      debugPrint('❌ Error opening settings: $e');
      return false;
    }
  }
}