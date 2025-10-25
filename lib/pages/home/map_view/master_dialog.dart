import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';


import '../../../services/api_services/auth_service.dart';
import '../../../widgets/animated_text_field.dart';
import '../../../constants/styles.dart';
import '../../../services/user_service.dart';
import '../../../models/user.dart';
import '../../../utils/phone_validator.dart';

Future<void> showMasterDialog(BuildContext context, {VoidCallback? onAuthorized, void Function(String phone)? onStartRegistration}) {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController phoneController = TextEditingController();

  return showDialog(
    context: context,
    useRootNavigator: true,
    builder: (BuildContext ctx) {
      return AlertDialog(
        backgroundColor: Styles().primaryColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        title: Row(
          children: [
            Icon(Icons.phone_android, color: Styles().titleColor),
            const SizedBox(width: 8),
            Text(
              FlutterI18n.translate(ctx, 'map_view.master_dialog.input_phone'),
              style: TextStyle(
                color: Styles().titleColor,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AnimatedTextField(
                keyboardType: TextInputType.phone,
                controller: phoneController,
                labelText: FlutterI18n.translate(ctx, 'map_view.master_dialog.input_phone'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return FlutterI18n.translate(ctx, 'required');
                  }
                  if (!PhoneValidator.validate(value)) {
                    return FlutterI18n.translate(ctx, 'invalid_phone');
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Styles().backgroundFormColor.withOpacity(0.6)),
                    foregroundColor: Styles().titleColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(FlutterI18n.translate(ctx, 'common.cancel')),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Styles().checkColor,
                    foregroundColor: Styles().titleColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () async {
                    if (!_formKey.currentState!.validate()) return;
                    final phone = phoneController.text.trim();

                    final needsRegistration = await AuthService().sendSms(phone);
                    if (!ctx.mounted) return;
                    Navigator.pop(ctx); // close phone dialog

                    _showOtpDialog(ctx, phone, needsRegistration, onAuthorized, onStartRegistration);
                  },
                  child: Text(FlutterI18n.translate(ctx, 'common.submit')),
                ),
              ),
            ],
          ),
        ],
      );
    },
  );
}

Future<void> _showOtpDialog(BuildContext context, String phone, bool needsRegistration, VoidCallback? onAuthorized, void Function(String phone)? onStartRegistration) {
  final TextEditingController codeController = TextEditingController();
  return showDialog(
    context: context,
    useRootNavigator: true,
    builder: (BuildContext ctx) {
      String? error;
      return StatefulBuilder(
        builder: (ctx, setState) {
          return AlertDialog(
            backgroundColor: Styles().primaryColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            title: Row(
              children: [
                Icon(Icons.lock_open_rounded, color: Styles().titleColor),
                const SizedBox(width: 8),
                Text(
                  FlutterI18n.translate(ctx, 'map_view.master_dialog.input_otp'),
                  style: TextStyle(
                    color: Styles().titleColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AnimatedTextField(
                  keyboardType: TextInputType.number,
                  controller: codeController,
                  labelText: FlutterI18n.translate(ctx, 'map_view.master_dialog.input_otp'),
                  validator: (_) {
                    if (error != null) return error;
                    return null;
                  },
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(error!, style: const TextStyle(color: Colors.red)),
                  ),
              ],
            ),
            actions: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Styles().backgroundFormColor.withOpacity(0.6)),
                        foregroundColor: Styles().titleColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(FlutterI18n.translate(ctx, 'common.cancel')),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Styles().checkColor,
                        foregroundColor: Styles().titleColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () async {
                        final code = codeController.text.trim();
                        if (code.isEmpty) {
                          setState(() { error = FlutterI18n.translate(ctx, 'required'); });
                          return;
                        }
                        final success = await AuthService()
                            .confirmLogin(phone, int.parse(code), ctx);
                        if (!success) {
                          setState(() {
                            error = FlutterI18n.translate(ctx, 'invalid_code');
                          });
                          return;
                        }

                        if (needsRegistration) {
                          Navigator.pop(ctx);
                          if (onStartRegistration != null) {
                            onStartRegistration(phone);
                          } else {
                            Navigator.pushReplacementNamed(
                              ctx,
                              '/map-picker',
                              arguments: {'phone': phone},
                            );
                          }
                        } else {
                          User? user = await UserService().getUser();
                          if (user != null && ctx.mounted) {
                            Navigator.pop(ctx);

                            if (onAuthorized != null) {
                              onAuthorized();
                            }
                          }
                        }
                      },
                      child: Text(FlutterI18n.translate(ctx, 'common.submit')),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      );
    },
  );
}
