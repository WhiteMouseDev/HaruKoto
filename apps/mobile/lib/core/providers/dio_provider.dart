import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../network/dio_client.dart';

final dioProvider = Provider((ref) => createDioClient());
