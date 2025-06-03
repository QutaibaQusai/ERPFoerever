import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io' show Platform;

class AppContactsService {
  static final AppContactsService _instance = AppContactsService._internal();
  factory AppContactsService() => _instance;
  AppContactsService._internal();

  Future<Map<String, dynamic>> getAllContacts() async {
    try {
      PermissionStatus permission = await Permission.contacts.status;

      if (Platform.isIOS) {
        try {
          bool flutterContactsPermission = await FlutterContacts.requestPermission();
          permission = await Permission.contacts.status;

          if (flutterContactsPermission) {
            List<Contact> contacts = await FlutterContacts.getContacts(
              withProperties: true,
              withThumbnail: false,
              withPhoto: false,
            );

            List<Map<String, dynamic>> contactsList = _processContactsForReturn(contacts);

            return {
              'success': true,
              'contacts': contactsList,
              'totalCount': contacts.length,
              'method': 'flutter_contacts_direct',
              'permissionStatus': permission.toString(),
            };
          }
        } catch (_) {}
      }

      if (permission.isDenied) {
        permission = await Permission.contacts.request();
      }

      if (permission.isPermanentlyDenied) {
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
        return {
          'success': false,
          'error': 'Contacts permission required but not granted.',
          'errorCode': 'PERMISSION_NOT_GRANTED',
          'contacts': [],
          'permissionStatus': permission.toString(),
          'diagnostic': 'Permission request failed or denied by user'
        };
      }

      List<Contact> contacts = await FlutterContacts.getContacts(
        withProperties: true,
        withThumbnail: false,
        withPhoto: false,
      );

      List<Map<String, dynamic>> contactsList = _processContactsForReturn(contacts);

      return {
        'success': true,
        'contacts': contactsList,
        'totalCount': contactsList.length,
        'permissionStatus': permission.toString(),
        'method': 'permission_handler',
        'diagnostic': 'SUCCESS: Retrieved contacts successfully'
      };

    } catch (e) {
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

  Future<void> printAllContactsToTerminal() async {
    try {
      List<Contact> contacts = await FlutterContacts.getContacts(
        withProperties: true,
        withThumbnail: false,
        withPhoto: false,
      );
    } catch (_) {}
  }

  Future<Map<String, dynamic>> checkiOSContactsAccess() async {
    try {
      PermissionStatus permissionHandlerStatus = await Permission.contacts.status;
      bool flutterContactsAccess = false;
      try {
        flutterContactsAccess = await FlutterContacts.requestPermission();
      } catch (_) {}

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

  Future<Map<String, dynamic>> forceRequestPermission() async {
    try {
      PermissionStatus currentStatus = await Permission.contacts.status;

      if (currentStatus.isPermanentlyDenied) {
        bool settingsOpened = await openAppSettings();
        return {
          'success': false,
          'message': 'Permission permanently denied. Settings opened: $settingsOpened',
          'action': 'settings_opened',
          'settings_opened': settingsOpened,
        };
      }

      PermissionStatus requestResult = await Permission.contacts.request();
      bool flutterResult = await FlutterContacts.requestPermission();
      PermissionStatus finalStatus = await Permission.contacts.status;

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
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to request permission',
      };
    }
  }

  Future<bool> openSettings() async {
    try {
      return await openAppSettings();
    } catch (_) {
      return false;
    }
  }
}
