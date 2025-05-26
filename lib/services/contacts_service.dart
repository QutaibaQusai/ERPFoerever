// lib/services/contacts_service.dart
import 'package:flutter/material.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:permission_handler/permission_handler.dart';

class AppContactsService {
  static final AppContactsService _instance = AppContactsService._internal();
  factory AppContactsService() => _instance;
  AppContactsService._internal();

  /// Get all contacts from device
  Future<Map<String, dynamic>> getAllContacts() async {
    try {
      debugPrint('📱 Starting contacts request...');

      // Check contacts permission
      PermissionStatus permission = await Permission.contacts.status;
      
      if (permission.isDenied) {
        debugPrint('🔐 Requesting contacts permission...');
        permission = await Permission.contacts.request();
        
        if (permission.isDenied) {
          debugPrint('❌ Contacts permission denied');
          return {
            'success': false,
            'error': 'Contacts permission denied',
            'errorCode': 'PERMISSION_DENIED',
            'contacts': []
          };
        }
      }

      if (permission.isPermanentlyDenied) {
        debugPrint('❌ Contacts permission permanently denied');
        return {
          'success': false,
          'error': 'Permissions and enable Contacts access.',
          'errorCode': 'PERMISSION_DENIED_FOREVER',
          'contacts': []
        };
      }

      debugPrint('✅ Contacts permission granted, fetching contacts...');

      // Get all contacts using the correct method name
      Iterable<Contact> contacts = await ContactsService.getContacts(
        withThumbnails: false,
        photoHighResolution: false,
        orderByGivenName: true,
      );

      List<Map<String, dynamic>> contactsList = [];

      for (Contact contact in contacts) {
        Map<String, dynamic> contactData = {
          'id': contact.identifier ?? '',
          'displayName': contact.displayName ?? '',
          'givenName': contact.givenName ?? '',
          'familyName': contact.familyName ?? '',
          'company': contact.company ?? '',
          'phones': [],
          'emails': [],
        };

        // Add phone numbers
        if (contact.phones != null && contact.phones!.isNotEmpty) {
          for (Item phone in contact.phones!) {
            contactData['phones'].add({
              'value': phone.value ?? '',
              'label': phone.label ?? 'mobile',
            });
          }
        }

        // Add email addresses
        if (contact.emails != null && contact.emails!.isNotEmpty) {
          for (Item email in contact.emails!) {
            contactData['emails'].add({
              'value': email.value ?? '',
              'label': email.label ?? 'home',
            });
          }
        }

        contactsList.add(contactData);
      }

      debugPrint('📞 Successfully fetched ${contactsList.length} contacts');

      return {
        'success': true,
        'contacts': contactsList,
        'totalCount': contactsList.length
      };

    } catch (e) {
      debugPrint('❌ Error getting contacts: $e');
      return {
        'success': false,
        'error': 'Failed to get contacts: ${e.toString()}',
        'errorCode': 'UNKNOWN_ERROR',
        'contacts': []
      };
    }
  }

  /// Open app settings
    Future<bool> openSettings() async {
    try {
      return await openAppSettings();
    } catch (e) {
      debugPrint('❌ Error opening app settings: $e');
      return false;
    }
  }
}