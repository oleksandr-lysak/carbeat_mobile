import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:carbeat/widgets/animated_dropdown_field.dart';
import 'package:carbeat/models/service.dart';
import 'dart:ui';
import 'package:carbeat/constants/styles.dart';

class MapFilterDialog extends StatefulWidget {
  final List<Service> services;
  final String? initialName;
  final int? initialServiceId;
  final double? initialRating;
  final bool? initialAvailable;
  final String? initialSort;
  final void Function({String? name, int? serviceId, double? rating, bool? available, String? sort}) onApply;

  const MapFilterDialog({
    super.key,
    required this.services,
    this.initialName,
    this.initialServiceId,
    this.initialRating,
    this.initialAvailable,
    this.initialSort,
    required this.onApply,
  });

  @override
  State<MapFilterDialog> createState() => _MapFilterDialogState();
}

class _MapFilterDialogState extends State<MapFilterDialog> {
  late TextEditingController nameController;
  DropdownItem? selectedService;
  double? selectedRating;
  bool? selectedAvailable;
  String? selectedSort;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.initialName ?? '');
    final items = widget.services.map((s) => DropdownItem(id: s.id, name: s.name)).toList();
    selectedService = widget.initialServiceId != null
        ? items.firstWhere((item) => item.id == widget.initialServiceId, orElse: () => items.first)
        : null;
    selectedRating = widget.initialRating;
    selectedAvailable = widget.initialAvailable;
    selectedSort = widget.initialSort;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final styles = Styles();

    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 0),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 36, 24, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    FlutterI18n.translate(context, 'cancel'),
                    style: TextStyle(fontWeight: FontWeight.w600, color: styles.primaryColor),
                  ),
                ),
                Text(
                  FlutterI18n.translate(context, 'map_view.filter_title'),
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: () {
                    widget.onApply(
                      name: nameController.text.isNotEmpty ? nameController.text : null,
                      serviceId: selectedService?.id,
                      rating: selectedRating,
                      available: selectedAvailable,
                      sort: selectedSort,
                    );
                    Navigator.of(context).pop();
                  },
                  child: Text(
                    FlutterI18n.translate(context, 'apply'),
                    style: TextStyle(fontWeight: FontWeight.w600, color: styles.primaryColor),
                  ),
                )
              ],
            ),
            const SizedBox(height: 16),


            Text(FlutterI18n.translate(context, 'filter'), style: theme.textTheme.labelMedium?.copyWith(color: Colors.grey)),
            SwitchListTile.adaptive(
              value: selectedAvailable ?? false,
              onChanged: (val) => setState(() => selectedAvailable = val),
              title: Text(
                FlutterI18n.translate(context, 'map_view.filter_available'),
                style: theme.textTheme.titleMedium,
              ),
              activeColor: Colors.green,
              contentPadding: EdgeInsets.zero,
            ),
            // Chips for Services
            const SizedBox(height: 12),
            Text(
              FlutterI18n.translate(context, 'map_view.filter_service'),
              style: theme.textTheme.titleMedium,
            ),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: widget.services.map((service) {
                final isSelected = selectedService?.id == service.id;
                return ChoiceChip(
                  label: Text(service.name),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        selectedService = DropdownItem(id: service.id, name: service.name);
                      } else {
                        selectedService = null;
                      }
                    });
                  },
                  selectedColor: styles.primaryColor,
                  backgroundColor: Colors.grey[200],
                  labelStyle: TextStyle(
                    color: isSelected ? styles.titleColor : Colors.black87,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 24),
            Text(FlutterI18n.translate(context, 'sort_by'), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),

            Wrap(
              spacing: 10,
              children: ['rating', 'name', 'distance'].map((sortOption) {
                final isSelected = selectedSort == sortOption;
                return ChoiceChip(
                  label: Text(
                    FlutterI18n.translate(context, 'map_view.sort_$sortOption'),
                  ),
                  selected: isSelected,
                  onSelected: (_) {
                    setState(() {
                      selectedSort = sortOption;
                    });
                  },
                  selectedColor: styles.primaryColor,
                  backgroundColor: Colors.grey[200],
                  labelStyle: TextStyle(
                    color: isSelected ? styles.titleColor : Colors.black87,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                );
              }).toList(),
            )
,


          ],
        ),
      ),
    );
  }
}
