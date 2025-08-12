import 'package:intl/intl.dart';

String formatDateTime(DateTime dt) {
  return DateFormat('yyyy-MM-dd HH:mm').format(dt);
}
