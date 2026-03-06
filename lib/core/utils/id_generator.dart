import 'package:uuid/uuid.dart';

final _uuid = Uuid();

String generateId() => _uuid.v4();

String generateShortId() => _uuid.v4().replaceAll('-', '').substring(0, 12);
