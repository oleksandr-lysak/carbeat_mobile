import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';


import '../../../services/api_services/auth_service.dart';
import '../../../widgets/animated_text_field.dart';
import '../../../services/user_service.dart';
import '../../../models/user.dart';
import '../../../utils/phone_validator.dart';

void showMasterDialog(BuildContext context, {VoidCallback? onAuthorized, void Function(String phone)? onStartRegistration}) {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController phoneController = TextEditingController();

  showDialog(
    context: context,
    builder: (BuildContext ctx) {
      return AlertDialog(
        title: Text(
          FlutterI18n.translate(ctx, 'map_view.master_dialog.input_phone'),
          style: Theme.of(ctx).textTheme.titleMedium,
        ),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
          TextButton(
            child: Text(FlutterI18n.translate(ctx, 'common.cancel')),
            onPressed: () => Navigator.pop(ctx),
          ),
          TextButton(
            child: Text(FlutterI18n.translate(ctx, 'common.submit')),
            onPressed: () async {
              if (!_formKey.currentState!.validate()) return;
              final phone = phoneController.text.trim();

              final needsRegistration = await AuthService().sendSms(phone);
              if (!ctx.mounted) return;
              Navigator.pop(ctx); // close phone dialog

              _showOtpDialog(ctx, phone, needsRegistration, onAuthorized, onStartRegistration);
            },
          ),
        ],
      );
    },
  );
}

void _showOtpDialog(BuildContext context, String phone, bool needsRegistration, VoidCallback? onAuthorized, void Function(String phone)? onStartRegistration) {
  final TextEditingController codeController = TextEditingController();
  showDialog(
    context: context,
    builder: (BuildContext ctx) {
      String? error;
      return StatefulBuilder(
        builder: (ctx, setState) {
          return AlertDialog(
            title: Text(
              FlutterI18n.translate(ctx, 'map_view.master_dialog.input_otp'),
              style: Theme.of(ctx).textTheme.titleMedium,
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
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
              TextButton(
                child: Text(FlutterI18n.translate(ctx, 'common.cancel')),
                onPressed: () => Navigator.pop(ctx),
              ),
              TextButton(
                child: Text(FlutterI18n.translate(ctx, 'common.submit')),
                onPressed: () async {
                  final success = await AuthService()
                      .confirmLogin(phone, int.parse(codeController.text), ctx);
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
              ),
            ],
          );
        },
      );
    },
  );
}
