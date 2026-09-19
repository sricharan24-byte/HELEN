import '../entities/emergency_contact.dart';
import '../../core/result.dart';
import '../../core/failure.dart';

/// Pure-Dart abstract contract for emergency contacts storage and safety sharing.
abstract interface class IEmergencyContactRepository {
  /// Unmodifiable list of configured emergency contacts.
  List<EmergencyContact> get contacts;

  /// Adds a verified emergency contact.
  Future<Result<void, Failure>> addContact(EmergencyContact contact);

  /// Removes an emergency contact at [index].
  Future<Result<void, Failure>> removeContact(int index);
}
