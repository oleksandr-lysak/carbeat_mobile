// ignore_for_file: unused_local_variable

import 'package:carbeat/constants/app_constants.dart';
import 'package:loggme/loggme.dart';

class LogService {
  static Future<void> log(String message,
      {String codeLanguage = 'dart', String type = 'error'}) async {
    const maxMessageLength = 800;
    List<String> messageParts = [];

    for (int i = 0; i < message.length; i += maxMessageLength) {
      final endIndex = (i + maxMessageLength < message.length)
          ? i + maxMessageLength
          : message.length;
      messageParts.add(message.substring(i, endIndex));
    }

    for (var part in messageParts) {
      final telegramMessage = TelegramLoggMessage()..addCodeText('$part\n');

      /// Send on multiple channels (telegram, slack, and custom)
      final logger = Logger(
          slackChannelsSenders: null,
          telegramChannelsSenders: AppConstants().telegramChannelsSenders);

      final responses = await logger.logs(telegramLoggMessage: telegramMessage);
    }
  }
}
