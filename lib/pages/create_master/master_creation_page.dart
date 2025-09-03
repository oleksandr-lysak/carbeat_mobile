import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:carbeat/constants/styles.dart';
import 'package:carbeat/widgets/animated_dropdown_field.dart';
import 'package:carbeat/widgets/animated_text_field.dart';
import 'package:carbeat/widgets/loading.dart';
import 'package:provider/provider.dart'; 
import 'package:carbeat/providers/service_provider.dart';
import 'package:latlong2/latlong.dart' as latlong;
import 'package:carbeat/utils/phone_validator.dart';



class MasterCreationPage extends StatefulWidget {
  const MasterCreationPage({super.key});

  @override
  MasterCreationPageState createState() => MasterCreationPageState();
}

class MasterCreationPageState extends State<MasterCreationPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  // ignore: unused_field
  latlong.LatLng? _selectedLocation;
  DropdownItem? selectedItem;
  bool _initializedFromArgs = false; // Ensure we only parse route args once

  @override
  void dispose() {
    _phoneController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Ініціалізація даних з провайдера
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ServiceProvider>(context, listen: false).loadSpecialties();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Отримання провайдера
    final serviceProvider = Provider.of<ServiceProvider>(context);
    final args = ModalRoute.of(context)?.settings.arguments;
    if (!_initializedFromArgs && args != null) {
      // Initialize from route arguments only once
      if (args is Map) {
        final dynamic phoneArg = args['phone'];
        if (phoneArg is String && _phoneController.text.isEmpty) {
          _phoneController.text = phoneArg;
        }
        final dynamic locationArg = args['location'];
        if (locationArg is latlong.LatLng) {
          _selectedLocation = locationArg;
        }
      } else if (args is latlong.LatLng) {
        // Backward compatibility: direct LatLng passed as argument
        _selectedLocation = args;
      }
      _initializedFromArgs = true;
    }

    if (serviceProvider.isLoading) {
      return Scaffold(
        appBar: AppBar(
            title: Text(FlutterI18n.translate(context, 'create_master'))),
        body: const Center(child: Loading()),
      );
    }

    if (serviceProvider.errorMessage != null) {
      return Scaffold(
        appBar: AppBar(
            title: Text(FlutterI18n.translate(context, 'create_master'))),
        body: Center(child: Text('Error: ${serviceProvider.errorMessage}')),
      );
    }

    return Stack(children: [
      Scaffold(
        backgroundColor: Colors.white,
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                AnimatedTextField(
                  controller: _phoneController,
                  labelText: '${FlutterI18n.translate(context, 'phone')} (+380 xxx xx xx)',
                  hintText: FlutterI18n.translate(context, 'enter_phone'),
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return FlutterI18n.translate(context, 'required');
                    }
                    if (!PhoneValidator.validate(value)) {
                      return FlutterI18n.translate(context, 'invalid_phone');
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                AnimatedTextField(
                  controller: _nameController,
                  labelText: FlutterI18n.translate(context, 'name'),
                  hintText: FlutterI18n.translate(context, 'enter_name'),
                  validator: (value) => value?.isEmpty ?? true
                      ? FlutterI18n.translate(context, 'required')
                      : null,
                ),
                const SizedBox(height: 20),
                AnimatedTextField(
                  controller: _descriptionController,
                  labelText: FlutterI18n.translate(context, 'description'),
                  hintText: FlutterI18n.translate(context, 'enter_description'),
                  maxLines: 3,
                  validator: (value) => value?.isEmpty ?? true
                      ? FlutterI18n.translate(context, 'required')
                      : null,
                ),
                const SizedBox(height: 20),
                AnimatedDropdownField(
                  labelText: FlutterI18n.translate(context, 'select_speciality'),
                  hintText: FlutterI18n.translate(context, 'choose_speciality'),
                  items: serviceProvider.services
                      .map((service) =>
                      DropdownItem(id: service.id, name: service.name))
                      .toList(),
                  selectedItem: selectedItem,
                  validator: (value) => value?.id.isNaN ?? true
                      ? FlutterI18n.translate(context, 'required')
                      : null,
                  onChanged: (DropdownItem? value) {
                    setState(() {
                      selectedItem = value;
                    });
                  },
                ),
              ],

            ),
          ),
        ),

      )  ,
      Positioned(
        left: MediaQuery.of(context).size.width * 0.3,
        right: MediaQuery.of(context).size.width * 0.3,
        bottom: MediaQuery.of(context).size.height * 0.02,
        child: ElevatedButton(
          style: ButtonStyle(
            backgroundColor: MaterialStateProperty.all(Styles().primaryColor),
            shape: MaterialStateProperty.all(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30.0),
              ),
            ),
          ),
          onPressed: () {
            Navigator.pushNamed(
              context,
              '/choose-photo',
              arguments: [_selectedLocation, _phoneController.text, _nameController.text, _descriptionController.text, selectedItem?.id],
            );
          },
          child: Text(
            '${FlutterI18n.translate(context, 'next')} ...',
            style: TextStyle(color: Styles().titleColor, fontSize: 24),
          ),
        ),
      ),
    ],);

  }

  // ignore: unused_element
  void _submit() {
    if (_formKey.currentState!.validate()) {
      // Your submit logic here
    }
  }
}
