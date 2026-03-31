/// Run this script once to create the `tow_requests` collection in PocketBase.
///
/// Usage:
///   dart run tool/setup_pocketbase.dart <admin_email> <admin_password>
///
/// Example:
///   dart run tool/setup_pocketbase.dart admin@example.com mysecretpassword
library;

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

const String pocketBaseUrl = 'http://127.0.0.1:8090';

Future<void> main(List<String> args) async {
  if (args.length < 2) {
    stderr.writeln('Usage: dart run tool/setup_pocketbase.dart <admin_email> <admin_password>');
    exit(1);
  }

  final email = args[0];
  final password = args[1];

  // 1. Authenticate as superuser (PocketBase v0.23+)
  print('Authenticating as admin...');
  final authRes = await http.post(
    Uri.parse('$pocketBaseUrl/api/collections/_superusers/auth-with-password'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'identity': email, 'password': password}),
  );

  if (authRes.statusCode != 200) {
    stderr.writeln('Failed to authenticate: ${authRes.body}');
    exit(1);
  }

  final token = jsonDecode(authRes.body)['token'] as String;
  print('Authenticated successfully.');

  // 2. Check if collection already exists
  final listRes = await http.get(
    Uri.parse('$pocketBaseUrl/api/collections/tow_requests'),
    headers: {'Authorization': token},
  );

  if (listRes.statusCode == 200) {
    print('Collection "tow_requests" already exists. Skipping creation.');
    exit(0);
  }

  // 3. Create the tow_requests collection
  print('Creating "tow_requests" collection...');

  final collectionBody = {
    'name': 'tow_requests',
    'type': 'base',
    'schema': [
      {
        'name': 'user',
        'type': 'relation',
        'required': true,
        'options': {
          'collectionId': '_pb_users_auth_',
          'cascadeDelete': false,
          'maxSelect': 1,
          'minSelect': null,
        },
      },
      {
        'name': 'pickup_location',
        'type': 'text',
        'required': true,
        'options': {'min': null, 'max': null, 'pattern': ''},
      },
      {
        'name': 'destination',
        'type': 'text',
        'required': true,
        'options': {'min': null, 'max': null, 'pattern': ''},
      },
      {
        'name': 'vehicle_type',
        'type': 'text',
        'required': true,
        'options': {'min': null, 'max': null, 'pattern': ''},
      },
      {
        'name': 'details',
        'type': 'text',
        'required': false,
        'options': {'min': null, 'max': null, 'pattern': ''},
      },
      {
        'name': 'service_timing',
        'type': 'text',
        'required': true,
        'options': {'min': null, 'max': null, 'pattern': ''},
      },
      {
        'name': 'status',
        'type': 'text',
        'required': true,
        'options': {'min': null, 'max': null, 'pattern': ''},
      },
      {
        'name': 'driver_name',
        'type': 'text',
        'required': false,
        'options': {'min': null, 'max': null, 'pattern': ''},
      },
      {
        'name': 'driver_rating',
        'type': 'number',
        'required': false,
        'options': {'min': null, 'max': null, 'noDecimal': false},
      },
      {
        'name': 'driver_total_rides',
        'type': 'number',
        'required': false,
        'options': {'min': null, 'max': null, 'noDecimal': true},
      },
      {
        'name': 'license_plate',
        'type': 'text',
        'required': false,
        'options': {'min': null, 'max': null, 'pattern': ''},
      },
      {
        'name': 'distance_km',
        'type': 'number',
        'required': false,
        'options': {'min': null, 'max': null, 'noDecimal': false},
      },
      {
        'name': 'eta_minutes',
        'type': 'number',
        'required': false,
        'options': {'min': null, 'max': null, 'noDecimal': true},
      },
      {
        'name': 'base_fare',
        'type': 'number',
        'required': false,
        'options': {'min': null, 'max': null, 'noDecimal': false},
      },
      {
        'name': 'distance_fare',
        'type': 'number',
        'required': false,
        'options': {'min': null, 'max': null, 'noDecimal': false},
      },
    ],
    // API rules: authenticated users can manage their own records
    'listRule': '@request.auth.id = user',
    'viewRule': '@request.auth.id = user',
    'createRule': '@request.auth.id != ""',
    'updateRule': '@request.auth.id = user',
    'deleteRule': '@request.auth.id = user',
  };

  final createRes = await http.post(
    Uri.parse('$pocketBaseUrl/api/collections'),
    headers: {
      'Authorization': token,
      'Content-Type': 'application/json',
    },
    body: jsonEncode(collectionBody),
  );

  if (createRes.statusCode == 200) {
    print('Collection "tow_requests" created successfully!');
    print('');
    print('Fields:');
    print('  user            -> Relation (users)');
    print('  pickup_location -> Text (required)');
    print('  destination     -> Text (required)');
    print('  vehicle_type    -> Text (required)');
    print('  details         -> Text');
    print('  service_timing  -> Text (required)');
    print('  status          -> Text (required)');
    print('  driver_name     -> Text');
    print('  driver_rating   -> Number');
    print('  driver_total_rides -> Number (integer)');
    print('  license_plate   -> Text');
    print('  distance_km     -> Number');
    print('  eta_minutes     -> Number (integer)');
    print('  base_fare       -> Number');
    print('  distance_fare   -> Number');
    print('');
    print('API Rules:');
    print('  List/View/Update/Delete: owner only (@request.auth.id = user)');
    print('  Create: any authenticated user');
  } else {
    stderr.writeln('Failed to create collection: ${createRes.body}');
    exit(1);
  }
}
